#!/usr/bin/env bash
# exit_codes.sh
# Central definitions of global exit codes for scripts and tests.
# These use default assignments so tests or callers can override them by exporting beforehand.
set -euo pipefail

# Initialize the exit codes array
EXIT_CODES=()

# Define exit codes and add them to the array
: "${EXIT_SUCCESS:=0}"
: "${DESC_EXIT_SUCCESS:=Success}"
EXIT_CODES+=("EXIT_SUCCESS")

: "${ERROR_DEFAULT:=1}"
: "${DESC_ERROR_DEFAULT:=Default error}"
EXIT_CODES+=("ERROR_DEFAULT")

: "${ERROR_USAGE:=64}"
: "${DESC_ERROR_USAGE:=Command line usage error}"
EXIT_CODES+=("ERROR_USAGE")

: "${ERROR_NO_INTERNET:=65}"
: "${DESC_ERROR_NO_INTERNET:=No internet access}"
EXIT_CODES+=("ERROR_NO_INTERNET")

: "${ERROR_ENV_FILE_MISSING:=66}"
: "${DESC_ERROR_ENV_FILE_MISSING:=Environment file missing}"
EXIT_CODES+=("ERROR_ENV_FILE_MISSING")

: "${ERROR_FUNCTION_NOT_FOUND:=67}"
: "${DESC_ERROR_FUNCTION_NOT_FOUND:=Function not found}"
EXIT_CODES+=("ERROR_FUNCTION_NOT_FOUND")

: "${ERROR_DOMAIN_RESOLVE:=68}"
: "${DESC_ERROR_DOMAIN_RESOLVE:=Failed to resolve domain}"
EXIT_CODES+=("ERROR_DOMAIN_RESOLVE")

: "${ERROR_INVALID_SITE_IP:=69}"
: "${DESC_ERROR_INVALID_SITE_IP:=Invalid site IP}"
EXIT_CODES+=("ERROR_INVALID_SITE_IP")

: "${ERROR_CURRENT_IP_FAIL:=70}"
: "${DESC_ERROR_CURRENT_IP_FAIL:=Failed to retrieve current IP}"
EXIT_CODES+=("ERROR_CURRENT_IP_FAIL")

: "${ERROR_SITE_IP_MISMATCH:=71}"
: "${DESC_ERROR_SITE_IP_MISMATCH:=Site IP mismatch}"
EXIT_CODES+=("ERROR_SITE_IP_MISMATCH")

: "${ERROR_BUILD_FAILED:=72}"
: "${DESC_ERROR_BUILD_FAILED:=Build failed}"
EXIT_CODES+=("ERROR_BUILD_FAILED")

: "${ERROR_PROXY_CONTAINER_START_FAILED:=73}"
: "${DESC_ERROR_PROXY_CONTAINER_START_FAILED:=Proxy containers failed to start}"
EXIT_CODES+=("ERROR_PROXY_CONTAINER_START_FAILED")

: "${ERROR_PROXY_LOCATION_NOT_FOUND:=74}"
: "${DESC_ERROR_PROXY_LOCATION_NOT_FOUND:=Proxy location not found or is invalid}"
EXIT_CODES+=("ERROR_PROXY_LOCATION_NOT_FOUND")

: "${ERROR_PROXY_CLONE_FAILED:=75}"
: "${DESC_ERROR_PROXY_CLONE_FAILED:=Proxy clone and setup failed}"
EXIT_CODES+=("ERROR_PROXY_CLONE_FAILED")

# Helper function to generate exit codes display for usage
print_exit_codes() {
    local var_name code desc_var description
    echo "Exit Codes:"
    for var_name in "${EXIT_CODES[@]}"; do
        code=${!var_name}
        desc_var="DESC_${var_name}"
        # Check if description variable exists, use a default if not
        if [[ -n "${!desc_var+x}" ]]; then
            description="${!desc_var}"
        else
            description="No description available"
        fi
        printf "  %-6s%s\n" "$code" "$description"
    done
}