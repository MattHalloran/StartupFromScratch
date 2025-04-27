#!/usr/bin/env bash
# exit_codes.sh
# Central definitions of global exit codes for scripts and tests.
# These use default assignments so tests or callers can override them by exporting beforehand.
set -euo pipefail

: "${EXIT_SUCCESS:=0}"
: "${DESC_EXIT_SUCCESS:=Success}"

: "${ERROR_DEFAULT:=1}"
: "${DESC_ERROR_DEFAULT:=Default error}"

: "${ERROR_USAGE:=64}"
: "${DESC_ERROR_USAGE:=Command line usage error}"

: "${ERROR_NO_INTERNET:=65}"
: "${DESC_ERROR_NO_INTERNET:=No internet access}"

: "${ERROR_ENV_FILE_MISSING:=66}"
: "${DESC_ERROR_ENV_FILE_MISSING:=Environment file missing}"

: "${ERROR_FUNCTION_NOT_FOUND:=67}"
: "${DESC_ERROR_FUNCTION_NOT_FOUND:=Function not found}"

: "${ERROR_DOMAIN_RESOLVE:=68}"
: "${DESC_ERROR_DOMAIN_RESOLVE:=Failed to resolve domain}"

: "${ERROR_INVALID_SITE_IP:=69}"
: "${DESC_ERROR_INVALID_SITE_IP:=Invalid site IP}"

: "${ERROR_CURRENT_IP_FAIL:=70}"
: "${DESC_ERROR_CURRENT_IP_FAIL:=Failed to retrieve current IP}"

: "${ERROR_SITE_IP_MISMATCH:=71}"
: "${DESC_ERROR_SITE_IP_MISMATCH:=Site IP mismatch}"

: "${ERROR_BUILD_FAILED:=72}"
: "${DESC_ERROR_BUILD_FAILED:=Build failed}"

: "${ERROR_PROXY_CONTAINER_START_FAILED:=73}"
: "${DESC_ERROR_PROXY_CONTAINER_START_FAILED:=Proxy containers failed to start}"

: "${ERROR_PROXY_LOCATION_NOT_FOUND:=74}"
: "${DESC_ERROR_PROXY_LOCATION_NOT_FOUND:=Proxy location not found or is invalid}"

: "${ERROR_PROXY_CLONE_FAILED:=75}"
: "${DESC_ERROR_PROXY_CLONE_FAILED:=Proxy clone and setup failed}"

# Helper function to generate exit codes display for usage
print_exit_codes() {
    local var_name code desc_var description
    echo "Exit Codes:"
    for var_name in EXIT_SUCCESS ERROR_DEFAULT ERROR_USAGE ERROR_NO_INTERNET ERROR_ENV_FILE_MISSING ERROR_FUNCTION_NOT_FOUND; do
        code=${!var_name}
        desc_var="DESC_${var_name}"
        description=${!desc_var}
        printf "  %-6s%s\n" "$code" "$description"
    done
}