#!/usr/bin/env bash
# shellcheck disable=SC2148

# --- Vault Utility Functions ---

# Verifies that required command-line tools (curl, jq) are installed.
# Exits with an error code if dependencies are missing.
check_vault_dependencies() {
    if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        error "Required dependencies 'curl' and 'jq' are missing."
        exit "${ERROR_MISSING_DEPENDENCIES:-88}"
    fi
}

# Parses and validates Vault API responses.
# Arguments:
#   $1: HTTP status code from curl
#   $2: Response body from curl
# Exits with an error code if the response indicates failure.
validate_vault_response() {
    local status="$1"
    local body="$2"
    if [ "$status" -lt 200 ] || [ "$status" -ge 300 ]; then
        error "Vault API request failed with status $status"
        return "${ERROR_VAULT_SECRET_FETCH_FAILED:-87}"
    fi
    return 0
}

# Handles differences between KV v1 and KV v2 secret engines when parsing data.
# Arguments:
#   $1: Raw JSON response body from Vault
#   $2: Vault secret path (used to determine KV version)
# Outputs:
#   JSON object containing the secret data.
handle_kv_version() {
    local raw_json="$1"
    local secret_path="$2"
    # KV v2 paths contain '/data/'
    if echo "$secret_path" | grep -q '/data/'; then
        # KV v2: data nested under .data.data
        echo "$raw_json" | jq '.data.data'
    else
        # KV v1: data under .data
        echo "$raw_json" | jq '.data'
    fi
}

# Extracts key-value pairs from a Vault JSON response and exports them as environment variables.
# Arguments:
#   $1: JSON object containing the secret data (output from handle_kv_version)
extract_secrets() {
    local secrets_json="$1"
    for key in $(echo "$secrets_json" | jq -r 'keys[]'); do
        local value
        value=$(echo "$secrets_json" | jq -r --arg k "$key" '.[$k]')
        export "$key"="$value"
        info "Exported secret '$key'"
    done
}

# Checks if the Vault server is initialized, unsealed, and active.
# Uses the /v1/sys/health endpoint.
# Returns 0 if healthy, non-zero otherwise.
check_vault_health() {
    local health_url="${VAULT_ADDR}/v1/sys/health"
    local response
    local http_code

    info "Checking Vault health at ${health_url}..."

    # Use curl to get health status. Handle self-signed certs in dev (-k).
    # Timeout ensures script doesn't hang indefinitely.
    response=$(curl --connect-timeout 5 -k -s -w "\n%{http_code}" "${health_url}")
    # Extract body and status code
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')

    if [ "$http_code" -ne 200 ]; then
        error "Vault health check failed: Received HTTP status $http_code from $health_url"
        # Distinguish connection refused error (might be 000 from curl timeout/refused)
        if [ "$http_code" = "000" ]; then 
            error "Could not connect to Vault at $VAULT_ADDR. Is it running?"
        fi
        return "${ERROR_VAULT_CONNECTION_FAILED:-30}"
    fi

    # Check JSON content using jq
    if ! echo "$response_body" | jq -e '.initialized == true and .sealed == false and .standby == false' > /dev/null; then
        error "Vault is reachable but not ready (initialized, unsealed, and active)."
        # Determine specific reason (optional)
        if echo "$response_body" | jq -e '.initialized == false' >/dev/null; then error "Reason: Vault is not initialized."; fi
        if echo "$response_body" | jq -e '.sealed == true' >/dev/null; then error "Reason: Vault is sealed."; fi
        if echo "$response_body" | jq -e '.standby == true' >/dev/null; then error "Reason: Vault is in standby mode."; fi
        return "${ERROR_VAULT_AUTH_FAILED:-31}" # Using AUTH_FAILED as a proxy for 'not ready'
    fi

    success "Vault is initialized, unsealed, and active."
    return 0
}

# Implements retry logic for Vault operations that might fail transiently.
# Arguments:
#   $1: Maximum number of retries
#   $2: Delay between retries (in seconds)
#   $@: Command to execute and retry
retry_vault_operation() {
    local max_retries="$1"
    local delay="$2"
    shift 2
    local cmd=("${@}")
    local attempt=1
    until [ "$attempt" -gt "$max_retries" ]; do
        if "${cmd[@]}"; then
            return 0
        fi
        info "Retry $attempt/$max_retries failed for: ${cmd[*]}"
        sleep "$delay"
        attempt=$((attempt + 1))
    done
    error "All $max_retries retries failed for: ${cmd[*]}"
    return "${ERROR_VAULT_SECRET_FETCH_FAILED:-87}"
} 