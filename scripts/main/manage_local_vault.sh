#!/usr/bin/env bash
# Manages a LOCAL Vault instance for development purposes.
# WARNING: This script is NOT for production Vault management.
set -euo pipefail
DESCRIPTION="Manages a LOCAL Vault instance (start/stop/status), with AppRole setup and optional dev secret seeding for DEVELOPMENT ONLY."

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"

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
    info "Checking Vault status at $VAULT_ADDR..."
    if vault status > /dev/null 2>&1; then
        success "Vault is responding."
        vault status # Print full status
        return 0
    else
        error "Vault at $VAULT_ADDR is not responding."
        return 1
    fi
}

# Starts Vault in development mode.
start_local_vault_dev() {
    if is_local_vault_running; then
        warning "Local Vault appears to be running already (PID: $(cat "$LOCAL_VAULT_PID_FILE"))."
        check_vault_status
        return 0
    fi

    if ! command -v vault > /dev/null; then
        error "Vault CLI not found. Please run setup first or install manually."
        exit "${ERROR_DEPENDENCY_MISSING:-5}"
    fi

    info "Starting local Vault server in DEV mode..."
    info "  Address: $VAULT_ADDR"
    info "  Root Token: $VAULT_DEV_ROOT_TOKEN_ID"
    info "  Log File: $LOCAL_VAULT_LOG"

    # Start in background, redirect output, store PID
    vault server -dev -dev-listen-address="${VAULT_ADDR#*//}" -dev-root-token-id="$VAULT_DEV_ROOT_TOKEN_ID" > "$LOCAL_VAULT_LOG" 2>&1 &
    local vault_pid=$!
    echo "$vault_pid" > "$LOCAL_VAULT_PID_FILE"

    # Wait for Vault to become responsive
    local max_attempts=10
    local attempt=1
    info "Waiting for Vault to start (PID: $vault_pid)..."
    while [ $attempt -le $max_attempts ]; do
        # Use curl for health check as vault status might require login
        if curl -k -s "$VAULT_ADDR/v1/sys/health" | jq -e '.initialized == true and .sealed == false and .standby == false' > /dev/null 2>&1; then
            success "Vault started successfully (PID: $vault_pid)."
            success "Use 'vault login $VAULT_DEV_ROOT_TOKEN_ID' to authenticate."
            return 0
        fi
        info "Waiting... (Attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done

    error "Vault did not start responding within the expected time."
    error "Check logs in $LOCAL_VAULT_LOG"
    # Clean up PID file if startup failed
    rm -f "$LOCAL_VAULT_PID_FILE"
    exit "${ERROR_OPERATION_FAILED:-7}"
}

# Stops the local Vault process.
stop_local_vault() {
    if ! is_local_vault_running; then
        info "Local Vault does not appear to be running."
        return 0
    fi

    local pid
    pid=$(cat "$LOCAL_VAULT_PID_FILE")
    info "Stopping local Vault process (PID: $pid)..."

    # Try graceful shutdown first, then force
    if kill "$pid" > /dev/null 2>&1; then
        sleep 1 # Give it a moment
        if ps -p "$pid" > /dev/null; then
            warning "Graceful shutdown failed, sending SIGKILL..."
            kill -9 "$pid" || true
        fi
        success "Vault process (PID: $pid) stopped."
    else
        warning "Process with PID $pid not found or could not be signaled. It might have already stopped."
    fi

    rm -f "$LOCAL_VAULT_PID_FILE"
    success "Cleaned up PID file."
    return 0
}

# Seeds default development credentials into Vault's KV engine at the 'secret/vrooli/dev' path.
seed_local_dev_secrets() {
    header "🌱 Seeding .env-dev variables into Vault KV at 'secret/vrooli/dev'..."
    local env_file="$HERE/../../.env-dev"
    if [ ! -f "$env_file" ]; then
        warning "No .env-dev file found at $env_file; skipping seeding."
        return 0
    fi
    info "Loading environment variables from $env_file"
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
    # Compute derived URLs and append them
    local computed_db_url="DB_URL=postgresql://${DB_USER}:${DB_PASSWORD}@db:${PORT_DB:-5432}"
    local computed_redis_url="REDIS_URL=redis://:${REDIS_PASSWORD}@redis:${PORT_REDIS:-6379}"
    kv_pairs+=("$computed_db_url" "$computed_redis_url")
    if [ ${#kv_pairs[@]} -eq 0 ]; then
        warning "No variables found to seed in $env_file"
        return 0
    fi
    info "Seeding ${#kv_pairs[@]} entries to Vault path: secret/vrooli/dev"
    # Write all collected pairs including computed URLs using the root token
    VAULT_TOKEN="$VAULT_DEV_ROOT_TOKEN_ID" vault kv put secret/vrooli/dev "${kv_pairs[@]}"
    success "Seeded ${#kv_pairs[@]} variables (including DB_URL and REDIS_URL) to Vault successfully."
}

# --- Placeholder/TODO Functions ---

# Basic setup for AppRole (useful for local dev)
# Configures the local dev Vault instance with an AppRole auth backend,
# a basic policy, and a role for the application.
setup_local_approle_dev() {
    header "🚀 Setting up AppRole for Local Dev Vault..."

    # Check if Vault is running
    if ! is_local_vault_running; then
        error "Local Vault is not running. Please start it first using --start-dev."
        return 1
    fi
    # Check if Vault is healthy (unsealed)
    # VAULT_ADDR is implicitly used by check_vault_health via curl
    if ! check_vault_health; then
        error "Vault is running but not healthy/unsealed. Cannot configure AppRole."
        return 1
    fi

    # Ensure we are logged in (use the known dev root token)
    info "Logging in with dev root token ('$VAULT_DEV_ROOT_TOKEN_ID')..."
    if ! VAULT_ADDR=$VAULT_ADDR vault login -no-print "$VAULT_DEV_ROOT_TOKEN_ID"; then
        error "Failed to login with Vault dev root token."
        return 1
    fi
    success "Logged in successfully."
    # Re-exporting might not be necessary now, but doesn't hurt
    export VAULT_ADDR

    # 1. Enable AppRole Auth Method (idempotent)
    info "Ensuring approle auth method is enabled..."
    if ! VAULT_ADDR=$VAULT_ADDR vault auth list | grep -q 'approle/'; then
        VAULT_ADDR=$VAULT_ADDR vault auth enable approle || {
            error "Failed to enable approle auth method."
            return 1
        }
        success "AppRole auth method enabled."
    else
        info "AppRole auth method already enabled."
    fi

    # 2. Define and Write Policy (idempotent)
    local policy_name="vrooli-app-policy"
    info "Ensuring policy '$policy_name' exists..."
    local policy_content='path "secret/data/vrooli/*" { capabilities = ["read", "list"] }'
    # Check if policy exists
    if ! VAULT_ADDR=$VAULT_ADDR vault policy read "$policy_name" > /dev/null 2>&1; then
        # Write policy if it doesn't exist
        echo "$policy_content" | VAULT_ADDR=$VAULT_ADDR vault policy write "$policy_name" - || {
            error "Failed to write policy '$policy_name'."
            return 1
        }
        success "Policy '$policy_name' created."
    else
        info "Policy '$policy_name' already exists."
    fi

    # 3. Create AppRole Role (idempotent)
    local role_name="vrooli-app-role"
    info "Ensuring AppRole role '$role_name' exists..."
    # Check if role exists
    if ! VAULT_ADDR=$VAULT_ADDR vault read "auth/approle/role/$role_name" > /dev/null 2>&1; then
        # Create role if it doesn't exist
        VAULT_ADDR=$VAULT_ADDR vault write "auth/approle/role/$role_name" \
            token_ttl=1h \
            token_max_ttl=4h \
            policies="default,$policy_name" || {
                error "Failed to create AppRole role '$role_name'."
                return 1
            }
        success "AppRole role '$role_name' created."
    else
        info "AppRole role '$role_name' already exists."
    fi

    # 4. Get RoleID
    info "Fetching RoleID for role '$role_name'..."
    local role_id
    # Use -format=json and jq for reliable field extraction
    # Read from the specific role-id sub-path
    role_id=$(VAULT_ADDR=$VAULT_ADDR vault read -format=json "auth/approle/role/$role_name/role-id" | jq -r .data.role_id)
    if [ -z "$role_id" ] || [ "$role_id" == "null" ]; then
        error "Failed to fetch RoleID for role '$role_name'."
        # Attempt to read again without jq for debugging
        VAULT_ADDR=$VAULT_ADDR vault read "auth/approle/role/$role_name/role-id"
        return 1
    fi
    success "Fetched RoleID ($role_id)."

    # 5. Generate SecretID
    info "Generating new SecretID for role '$role_name'..."
    local secret_id_data
    secret_id_data=$(VAULT_ADDR=$VAULT_ADDR vault write -f -format=json "auth/approle/role/$role_name/secret-id")
    if [ -z "$secret_id_data" ]; then
        error "Failed to generate SecretID for role '$role_name'."
        return 1
    fi
    local secret_id
    secret_id=$(echo "$secret_id_data" | jq -r .data.secret_id)
    local secret_id_accessor
    secret_id_accessor=$(echo "$secret_id_data" | jq -r .data.secret_id_accessor)
    if [ -z "$secret_id" ] || [ "$secret_id" == "null" ]; then
        error "Failed to parse SecretID from Vault response."
        return 1
    fi
    success "Generated new SecretID."

    # 6. Output instructions for .env-dev file
    header "Local Dev AppRole Configuration Complete"
    warning "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    warning "!! The following credentials are for LOCAL DEVELOPMENT/TESTING ONLY.       !!"
    warning "!! Do NOT use these in staging or production environments.                 !!"
    warning "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    info    "To use these credentials with your local application, update your '.env-dev' file:"
    echo    "------------------------------------------------------------------------------"
    echo    "# --- Vault Settings for Local Dev --- "
    echo    "SECRETS_SOURCE=vault" 
    echo    "VAULT_ADDR=$VAULT_ADDR" 
    echo    "VAULT_SECRET_PATH=secret/data/vrooli/dev # Or adjust as needed"
    echo    "VAULT_AUTH_METHOD=approle"
    echo    "VAULT_ROLE_ID=$role_id"
    echo    "VAULT_SECRET_ID=$secret_id"
    echo    "------------------------------------------------------------------------------"
    # Optional: Add instructions for other auth methods if needed for testing
    info "(For Token auth, use VAULT_AUTH_METHOD=token and VAULT_TOKEN=$VAULT_DEV_ROOT_TOKEN_ID)"
    info "(SecretID Accessor for reference: $secret_id_accessor)"

    # Logout from root token - REMOVED FOR IDEMPOTENCY ON DEV SERVER
    # VAULT_ADDR=$VAULT_ADDR vault token revoke -self > /dev/null
    # info "Logged out from root token."

    return 0
}

# Initialize Vault for production (persistent storage)
initialize_local_vault_prod() {
    echo "TODO vault admin: initialize_local_vault_prod"
    error "Local production Vault initialization not yet implemented."
    return 1
}

# Unseal production Vault
unseal_local_vault_prod() {
    echo "TODO vault admin: unseal_local_vault_prod"
    error "Local production Vault unsealing not yet implemented."
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
            error "Unknown option: $1"
            exit "${ERROR_USAGE:-1}"
            ;;
        esac
    done
    export ACTION
}

main() {
    parse_arguments "$@"
    header "🔧 Local Vault Management Utility (Dev Only) 🔧"

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
            error "Invalid action specified: $ACTION"
            exit "${ERROR_USAGE:-1}"
            ;;
    esac

    success "✅ Local Vault management task '$ACTION' completed."
}

main "$@" 