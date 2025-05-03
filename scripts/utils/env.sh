#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$HERE"/../.. && pwd)
ENV_DEV_FILE="$ROOT_DIR/.env-dev"
ENV_PROD_FILE="$ROOT_DIR/.env-prod"

# shellcheck disable=SC1091
source "${HERE}/../utils/logging.sh"
# shellcheck disable=SC1091
source "${HERE}/../utils/exit_codes.sh"
# shellcheck disable=SC1091
source "${HERE}/../utils/vault.sh"

# Load secrets from an environment file
load_env_file() {

    ENV_FILE="$ENV_PROD_FILE"
    if [ "$NODE_ENV" = "development" ]; then
        ENV_FILE="$ENV_DEV_FILE"
    fi

    if [ ! -f "$ENV_FILE" ]; then
        error "Error: Environment file $ENV_FILE does not exist."
        exit "${ERROR_ENV_FILE_MISSING}"
    fi

    info "Sourcing environment file $ENV_FILE"
    set -a
    # shellcheck source=/dev/null
    . "$ENV_FILE"
    set +a
}

# Authenticates to Vault using the token method.
# Requires VAULT_TOKEN to be set.
authenticate_with_token() {
    echo "TODO vault setup: authenticate_with_token"
    # TODO: Implement token authentication
    return 0
}

# Authenticates to Vault using the AppRole method.
# Requires VAULT_ROLE_ID and VAULT_SECRET_ID to be set.
authenticate_with_approle() {
    echo "TODO vault setup: authenticate_with_approle"
    # TODO: Implement AppRole authentication
    return 0
}

# Authenticates to Vault using the Kubernetes method.
# Requires VAULT_K8S_ROLE and access to the service account JWT.
authenticate_with_kubernetes() {
    echo "TODO vault setup: authenticate_with_kubernetes"
    # TODO: Implement Kubernetes authentication
    return 0
}

# Fetches secrets from the configured Vault path after successful authentication.
# Exports secrets as environment variables.
fetch_secrets_from_vault() {
    echo "TODO vault setup: fetch_secrets_from_vault"
    # TODO: Implement secret fetching using helper functions
    return 0
}

# Load secrets from HashiCorp Vault.
# Orchestrates authentication and secret retrieval based on environment variables.
load_vault_secrets() {
    info "Loading secrets from HashiCorp Vault..."

    # Ensure Vault address is set
    : "${VAULT_ADDR:?Required environment variable VAULT_ADDR is not set}"

    # 1. Check if Vault is healthy and ready
    if ! check_vault_health; then
        error "Aborting secret loading due to Vault health check failure."
        exit "${ERROR_VAULT_CONNECTION_FAILED:-30}"
    fi

    echo "TODO vault setup: load_vault_secrets"
    # 2. Check required base Vault env vars (VAULT_SECRET_PATH)
    : "${VAULT_SECRET_PATH:?Required environment variable VAULT_SECRET_PATH is not set}"

    # 3. Check client dependencies (curl, jq)
    # Note: vault CLI is not strictly needed if using curl/API only
    if ! check_command_exists "curl" || ! check_command_exists "jq"; then
        error "Required commands 'curl' or 'jq' not found. Please run setup or install them."
        exit "${ERROR_MISSING_DEPENDENCIES:-33}"
    fi

    # 4. Determine VAULT_AUTH_METHOD (default to token)
    local auth_method
    auth_method=$(echo "${VAULT_AUTH_METHOD:-token}" | tr '[:upper:]' '[:lower:]')

    # 5. Call appropriate authenticate_with_* function
    case "$auth_method" in
        token)
            authenticate_with_token
            ;;
        approle)
            authenticate_with_approle
            ;;
        kubernetes)
            authenticate_with_kubernetes
            ;;
        *)
            error "Unsupported VAULT_AUTH_METHOD: $auth_method"
            exit "${ERROR_USAGE:-1}"
            ;;
    esac

    # 6. Call fetch_secrets_from_vault
    fetch_secrets_from_vault

    # 7. Export derived variables (DB_URL, REDIS_URL) if needed
    # Ensure DB_USER, DB_PASSWORD, REDIS_PASSWORD etc. were exported by fetch_secrets_from_vault
    : "${DB_USER:?DB_USER not found in Vault secrets}"
    : "${DB_PASSWORD:?DB_PASSWORD not found in Vault secrets}"
    : "${REDIS_PASSWORD:?REDIS_PASSWORD not found in Vault secrets}"
    export DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@db:${PORT_DB:-5432}"
    export REDIS_URL="redis://:${REDIS_PASSWORD}@redis:${PORT_REDIS:-6379}"

    info "Vault secrets loaded and processed successfully"
    return 0
}

# Main function to load secrets based on the SECRETS_SOURCE environment variable.
load_secrets() {
    header "🔑 Loading secrets..."

    : "${SECRETS_SOURCE:?Required environment variable SECRETS_SOURCE is not set}"
    : "${ENVIRONMENT:?Required environment variable ENVIRONMENT is not set}"

    # Determine Node Env
    NODE_ENV="${NODE_ENV:-development}"
    case "$ENVIRONMENT" in
        [dD]*) NODE_ENV="development" ;;
        [pP]*) NODE_ENV="production" ;;
        *) error "Invalid environment: $ENVIRONMENT"; exit "${ERROR_USAGE:-1}" ;;
    esac

    # Determine the correct .env file to source
    local env_file_to_source="$ENV_PROD_FILE"
    if [ "$NODE_ENV" = "development" ]; then
        env_file_to_source="$ENV_DEV_FILE"
    fi

    # Source the primary .env file first to load base config (like VAULT_ADDR, etc.)
    # This makes these variables available regardless of SECRETS_SOURCE
    if [ -f "$env_file_to_source" ]; then
        info "Sourcing base environment file: $env_file_to_source"
        set -a
        # shellcheck source=/dev/null
        . "$env_file_to_source"
        set +a
    else
        # In containerized environments, the file might not exist, relying solely on injected vars
        info "Base environment file not found: $env_file_to_source. Relying on existing environment variables."
    fi

    # Now, load secrets based on the source type
    case "$(echo "$SECRETS_SOURCE" | tr '[:upper:]' '[:lower:]')" in
        e|env|environment|f|file)
            info "Using secrets from sourced environment file."
            # Check if required variables are present from the file
            : "${DB_USER:?DB_USER not found in environment/file when SECRETS_SOURCE=file}"
            : "${DB_PASSWORD:?DB_PASSWORD not found in environment/file when SECRETS_SOURCE=file}"
            : "${REDIS_PASSWORD:?REDIS_PASSWORD not found in environment/file when SECRETS_SOURCE=file}"
            # load_env_file function is now redundant as sourcing is done above
            ;;
        v|vault|hashicorp|hashicorp-vault)
            # Call the function to load secrets from Vault
            # This function assumes VAULT_* vars are now set (from file or injected env)
            # It will fetch and export secrets like DB_USER, DB_PASSWORD, etc., potentially overwriting sourced values.
            load_vault_secrets
            ;;
        *)
            error "Invalid secrets source: $SECRETS_SOURCE"
            exit "${ERROR_USAGE:-1}"
            ;;
    esac

    # Construct derived variables using the final values of DB_USER, DB_PASSWORD, etc.
    # These values came either directly from the .env file or were overwritten by load_vault_secrets
    info "Constructing derived variables (DB_URL, REDIS_URL)..."
    : "${DB_USER:?DB_USER was not set by environment file or Vault}"
    : "${DB_PASSWORD:?DB_PASSWORD was not set by environment file or Vault}"
    : "${REDIS_PASSWORD:?REDIS_PASSWORD was not set by environment file or Vault}"
    export DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@db:${PORT_DB:-5432}"
    export REDIS_URL="redis://:${REDIS_PASSWORD}@redis:${PORT_REDIS:-6379}"
    success "Secrets loaded and processed."
}

# Checks if the script is running in a CI environment.
is_running_in_ci() {
    [[ "$CI" == "true" ]]
}
