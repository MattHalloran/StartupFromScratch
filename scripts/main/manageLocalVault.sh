#!/usr/bin/env bash
# Manages a LOCAL Vault instance for development purposes.
# WARNING: This script is NOT for production Vault management.
set -euo pipefail
DESCRIPTION="Manages a LOCAL Vault instance (start/stop/status), with AppRole setup and optional dev secret seeding for DEVELOPMENT ONLY."

MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/flow.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/locations.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/log.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/system.sh"

# --- Configuration ---
# Default Vault address for local dev instance
# Ensure VAULT_ADDR is set, potentially from sourced files or exported
: "${VAULT_ADDR:=http://127.0.0.1:8200}"
export VAULT_ADDR
# Use a fixed root token for simplicity in dev mode (matches HashiCorp tutorial)
# Can be overridden by exporting VAULT_DEV_ROOT_TOKEN_ID
: "${VAULT_DEV_ROOT_TOKEN_ID:=root}"
export VAULT_DEV_ROOT_TOKEN_ID

LOCAL_VAULT_LOG=".vault-local.log"
LOCAL_VAULT_PID_FILE=".vault-local.pid"

# --- Helper Functions ---

# Helper function to read a PEM file, escape newlines, and prepare a 'key=value' string
prepare_pem_for_kv_pairs() {
    local key_name="$1"
    local file_path="$2"
    local file_content
    local escaped_content

    if [ ! -f "$file_path" ]; then
        log::warning "PEM file $file_path does not exist. Cannot prepare $key_name for Vault seeding."
        echo "" # Return empty string
        return
    fi

    file_content=$(cat "$file_path")

    if [ -z "$file_content" ]; then
        log::warning "PEM file $file_path is empty. Cannot prepare $key_name for Vault seeding."
        echo "" # Return empty string
        return
    fi

    # Escape newlines to store as a single line in Vault, using the sed method from user example
    escaped_content=$(echo -n "$file_content" | sed ':a;N;$!ba;s/\n/\\n/g')
    
    echo "$key_name=$escaped_content"
}

# Checks if a local Vault process seems to be running (based on PID file).
is_local_vault_running() {
    if [ -f "$LOCAL_VAULT_PID_FILE" ]; then
        local pid
        pid=$(cat "$LOCAL_VAULT_PID_FILE")
        if ps -p "$pid" > /dev/null; then
            return 0 # Process exists
        else
            # PID file exists but process doesn't - stale file?
            rm -f "$LOCAL_VAULT_PID_FILE"
            return 1
        fi
    fi
    return 1 # PID file doesn't exist
}

# Checks Vault status using the CLI.
check_vault_status() {
    log::info "Checking Vault status at $VAULT_ADDR..."
    if vault status > /dev/null 2>&1; then
        log::success "Vault is responding."
        vault status # Print full status
        return 0
    else
        log::error "Vault at $VAULT_ADDR is not responding."
        return 1
    fi
}

# Starts Vault in development mode.
start_local_vault_dev() {
    if is_local_vault_running; then
        log::warning "Local Vault appears to be running already (PID: $(cat "$LOCAL_VAULT_PID_FILE"))."
        check_vault_status
        return 0
    fi

    system::assert_command "vault" "Vault CLI not found. Please run setup first or install manually."

    log::info "Starting local Vault server in DEV mode..."
    log::info "  Address: $VAULT_ADDR"
    log::info "  Root Token: $VAULT_DEV_ROOT_TOKEN_ID"
    log::info "  Log File: $LOCAL_VAULT_LOG"

    # Start in background, redirect output, store PID
    vault server -dev -dev-listen-address="${VAULT_ADDR#*//}" -dev-root-token-id="$VAULT_DEV_ROOT_TOKEN_ID" > "$LOCAL_VAULT_LOG" 2>&1 &
    local vault_pid=$!
    echo "$vault_pid" > "$LOCAL_VAULT_PID_FILE"

    # Wait for Vault to become responsive
    local max_attempts=10
    local attempt=1
    log::info "Waiting for Vault to start (PID: $vault_pid)..."
    while [ $attempt -le $max_attempts ]; do
        # Use curl for health check as vault status might require login
        if curl -k -s "$VAULT_ADDR/v1/sys/health" | jq -e '.initialized == true and .sealed == false and .standby == false' > /dev/null 2>&1; then
            log::success "Vault started successfully (PID: $vault_pid)."
            log::success "Use 'vault login $VAULT_DEV_ROOT_TOKEN_ID' to authenticate."
            return 0
        fi
        log::info "Waiting... (Attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done

    log::error "Vault did not start responding within the expected time."
    log::error "Check logs in $LOCAL_VAULT_LOG"
    # Clean up PID file if startup failed
    rm -f "$LOCAL_VAULT_PID_FILE"
    exit "${ERROR_OPERATION_FAILED:-7}"
}

# Stops the local Vault process.
stop_local_vault() {
    if ! is_local_vault_running; then
        log::info "Local Vault does not appear to be running."
        return 0
    fi

    local pid
    pid=$(cat "$LOCAL_VAULT_PID_FILE")
    log::info "Stopping local Vault process (PID: $pid)..."

    # Try graceful shutdown first, then force
    if kill "$pid" > /dev/null 2>&1; then
        sleep 1 # Give it a moment
        if ps -p "$pid" > /dev/null; then
            log::warning "Graceful shutdown failed, sending SIGKILL..."
            kill -9 "$pid" || true
        fi
        log::success "Vault process (PID: $pid) stopped."
    else
        log::warning "Process with PID $pid not found or could not be signaled. It might have already stopped."
    fi

    rm -f "$LOCAL_VAULT_PID_FILE"
    log::success "Cleaned up PID file."
    return 0
}

# Seeds default development credentials into Vault's KV engine at the 'secret/vrooli/dev' path.
seed_local_dev_secrets() {
    log::header "🌱 Seeding .env-dev variables into Vault KV at 'secret/vrooli/dev'..."
    local env_file="$ENV_DEV_FILE"
    if [ ! -f "$env_file" ]; then
        log::warning "No .env-dev file found at $env_file; skipping seeding."
        return 0
    fi
    log::info "Loading environment variables from $env_file"
    # Export all .env-dev variables into this shell for computation
    set -a
    # shellcheck disable=SC1091
    . "$env_file"
    set +a
    # Collect key=value pairs, skipping Vault-specific and source keys
    mapfile -t kv_pairs < <(
        grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$env_file" \
        | grep -v -E '^(VAULT_|SECRETS_SOURCE)'
    )

    # -- NEW JWT HANDLING USING HELPER FUNCTION --
    log::info "Preparing JWT keys from PEM files for Vault seeding..."
    local jwt_priv_kv_entry
    jwt_priv_kv_entry=$(prepare_pem_for_kv_pairs "JWT_PRIV" "${ROOT_DIR}/jwt_priv.pem")
    if [ -n "$jwt_priv_kv_entry" ]; then
        kv_pairs+=("$jwt_priv_kv_entry")
        log::info "JWT_PRIV prepared for Vault seeding (content newline-escaped)."
    fi

    local jwt_pub_kv_entry
    jwt_pub_kv_entry=$(prepare_pem_for_kv_pairs "JWT_PUB" "${ROOT_DIR}/jwt_pub.pem")
    if [ -n "$jwt_pub_kv_entry" ]; then
        kv_pairs+=("$jwt_pub_kv_entry")
        log::info "JWT_PUB prepared for Vault seeding (content newline-escaped)."
    fi
    # -- END NEW JWT HANDLING --

    # Compute derived URLs and append them
    local computed_db_url="DB_URL=postgresql://${DB_USER}:${DB_PASSWORD}@postgres:${PORT_DB:-5432}"
    local computed_redis_url="REDIS_URL=redis://:${REDIS_PASSWORD}@redis:${PORT_REDIS:-6379}"
    local computed_worker_id="WORKER_ID=${WORKER_ID:-0}"
    kv_pairs+=("$computed_db_url" "$computed_redis_url" "$computed_worker_id")
    if [ ${#kv_pairs[@]} -eq 0 ]; then
        log::warning "No variables found to seed in $env_file"
        return 0
    fi
    log::info "Seeding ${#kv_pairs[@]} entries to Vault path: secret/vrooli/dev"
    # Write all collected pairs including computed URLs using the root token
    VAULT_TOKEN="$VAULT_DEV_ROOT_TOKEN_ID" vault kv put secret/vrooli/dev "${kv_pairs[@]}"
    log::success "Seeded ${#kv_pairs[@]} variables (including DB_URL and REDIS_URL) to Vault successfully."
}

# Basic setup for AppRole (useful for local dev)
# Configures the local dev Vault instance with an AppRole auth backend,
# a basic policy, and a role for the application.
setup_local_approle_dev() {
    log::header "🚀 Setting up AppRole for Local Dev Vault..."

    # Check if Vault is running
    if ! is_local_vault_running; then
        log::error "Local Vault is not running. Please start it first using --start-dev."
        return 1
    fi
    # Check if Vault is healthy (unsealed)
    # VAULT_ADDR is implicitly used by check_vault_health via curl
    if ! check_vault_health; then
        log::error "Vault is running but not healthy/unsealed. Cannot configure AppRole."
        return 1
    fi

    # Ensure we are logged in (use the known dev root token)
    log::info "Logging in with dev root token ('$VAULT_DEV_ROOT_TOKEN_ID')..."
    if ! VAULT_ADDR=$VAULT_ADDR vault login -no-print "$VAULT_DEV_ROOT_TOKEN_ID"; then
        log::error "Failed to login with Vault dev root token."
        return 1
    fi
    log::success "Logged in successfully."
    # Re-exporting might not be necessary now, but doesn't hurt
    export VAULT_ADDR

    # 1. Enable AppRole Auth Method (idempotent)
    log::info "Ensuring approle auth method is enabled..."
    if ! VAULT_ADDR=$VAULT_ADDR vault auth list | grep -q 'approle/'; then
        VAULT_ADDR=$VAULT_ADDR vault auth enable approle || {
            log::error "Failed to enable approle auth method."
            return 1
        }
        log::success "AppRole auth method enabled."
    else
        log::info "AppRole auth method already enabled."
    fi

    # 2. Define and Write Policy (idempotent)
    local policy_name="vrooli-app-policy"
    log::info "Ensuring policy '$policy_name' exists..."
    local policy_content='path "secret/data/vrooli/*" { capabilities = ["read", "list"] }'
    # Check if policy exists
    if ! VAULT_ADDR=$VAULT_ADDR vault policy read "$policy_name" > /dev/null 2>&1; then
        # Write policy if it doesn't exist
        echo "$policy_content" | VAULT_ADDR=$VAULT_ADDR vault policy write "$policy_name" - || {
            log::error "Failed to write policy '$policy_name'."
            return 1
        }
        log::success "Policy '$policy_name' created."
    else
        log::info "Policy '$policy_name' already exists."
    fi

    # 3. Create AppRole Role (idempotent)
    local role_name="vrooli-app-role"
    log::info "Ensuring AppRole role '$role_name' exists..."
    # Check if role exists
    if ! VAULT_ADDR=$VAULT_ADDR vault read "auth/approle/role/$role_name" > /dev/null 2>&1; then
        # Create role if it doesn't exist
        VAULT_ADDR=$VAULT_ADDR vault write "auth/approle/role/$role_name" \
            token_ttl=1h \
            token_max_ttl=4h \
            policies="default,$policy_name" || {
                log::error "Failed to create AppRole role '$role_name'."
                return 1
            }
        log::success "AppRole role '$role_name' created."
    else
        log::info "AppRole role '$role_name' already exists."
    fi

    # 4. Get RoleID
    log::info "Fetching RoleID for role '$role_name'..."
    local role_id
    # Use -format=json and jq for reliable field extraction
    # Read from the specific role-id sub-path
    role_id=$(VAULT_ADDR=$VAULT_ADDR vault read -format=json "auth/approle/role/$role_name/role-id" | jq -r .data.role_id)
    if [ -z "$role_id" ] || [ "$role_id" == "null" ]; then
        log::error "Failed to fetch RoleID for role '$role_name'."
        # Attempt to read again without jq for debugging
        VAULT_ADDR=$VAULT_ADDR vault read "auth/approle/role/$role_name/role-id"
        return 1
    fi
    log::success "Fetched RoleID ($role_id)."

    # 5. Generate SecretID
    log::info "Generating new SecretID for role '$role_name'..."
    local secret_id_data
    secret_id_data=$(VAULT_ADDR=$VAULT_ADDR vault write -f -format=json "auth/approle/role/$role_name/secret-id")
    if [ -z "$secret_id_data" ]; then
        log::error "Failed to generate SecretID for role '$role_name'."
        return 1
    fi
    local secret_id
    secret_id=$(echo "$secret_id_data" | jq -r .data.secret_id)
    local secret_id_accessor
    secret_id_accessor=$(echo "$secret_id_data" | jq -r .data.secret_id_accessor)
    if [ -z "$secret_id" ] || [ "$secret_id" == "null" ]; then
        log::error "Failed to parse SecretID from Vault response."
        return 1
    fi
    log::success "Generated new SecretID."

    # 6. Output instructions for .env-dev file
    log::header "Local Dev AppRole Configuration Complete"
    log::warning "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    log::warning "!! The following credentials are for LOCAL DEVELOPMENT/TESTING ONLY.       !!"
    log::warning "!! Do NOT use these in staging or production environments.                 !!"
    log::warning "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    log::info    "To use these credentials with your local application, update your '.env-dev' file:"
    log::info    "------------------------------------------------------------------------------"
    log::info    "# --- Vault Settings for Local Dev --- "
    log::info    "SECRETS_SOURCE=vault" 
    log::info    "VAULT_ADDR=$VAULT_ADDR" 
    log::info    "VAULT_SECRET_PATH=secret/data/vrooli/dev # Or adjust as needed"
    log::info    "VAULT_AUTH_METHOD=approle"
    log::info    "VAULT_ROLE_ID=$role_id"
    log::info    "VAULT_SECRET_ID=$secret_id"
    log::info    "------------------------------------------------------------------------------"
    # Optional: Add instructions for other auth methods if needed for testing
    log::info    "(For Token auth, use VAULT_AUTH_METHOD=token and VAULT_TOKEN=$VAULT_DEV_ROOT_TOKEN_ID)"
    log::info    "(SecretID Accessor for reference: $secret_id_accessor)"

    # Logout from root token - REMOVED FOR IDEMPOTENCY ON DEV SERVER
    # VAULT_ADDR=$VAULT_ADDR vault token revoke -self > /dev/null
    # info "Logged out from root token."

    return 0
}

# Initialize Vault for production (persistent storage)
initialize_local_vault_prod() {
    echo "TODO vault admin: initialize_local_vault_prod"
    log::error "Local production Vault initialization not yet implemented."
    return 1
}

# Unseal production Vault
unseal_local_vault_prod() {
    echo "TODO vault admin: unseal_local_vault_prod"
    log::error "Local production Vault unsealing not yet implemented."
    return 1
}

# --- Main Execution ---

parse_arguments() {
    ACTION="status" # Default action
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
        --start-dev)
            ACTION="start-dev"
            shift
            ;;
        --stop)
            ACTION="stop"
            shift
            ;;
        --status)
            ACTION="status"
            shift
            ;;
        -h | --help)
            echo "Usage: $0 [ACTION]"
            echo "Manages a LOCAL Vault server for DEVELOPMENT purposes only."
            echo ""
            echo "Actions:"
            echo "  --start-dev          Start Vault in dev mode, perform AppRole setup, and seed default dev credentials (requires running Vault & root login). (Default if no action)"
            echo "  --stop               Stop the running local Vault instance."
            echo "  --status             Check the status of the local Vault instance."
            echo "  -h, --help           Show this help message."
            echo ""
            echo "Environment Variables:"
            echo "  VAULT_ADDR (Default: http://127.0.0.1:8200)"
            echo "  VAULT_DEV_ROOT_TOKEN_ID (Default: root)"
            exit 0
            ;;
        *)
            log::error "Unknown option: $1"
            exit "${ERROR_USAGE:-1}"
            ;;
        esac
    done
    export ACTION
}

main() {
    parse_arguments "$@"
    log::header "🔧 Local Vault Management Utility (Dev Only) 🔧"

    case "$ACTION" in
        start-dev)
            start_local_vault_dev
            setup_local_approle_dev
            seed_local_dev_secrets
            ;;
        stop)
            stop_local_vault
            ;;
        status)
            check_vault_status
            ;;
        *)
            log::error "Invalid action specified: $ACTION"
            exit "${ERROR_USAGE:-1}"
            ;;
    esac

    log::success "✅ Local Vault management task '$ACTION' completed."
}

main "$@" 