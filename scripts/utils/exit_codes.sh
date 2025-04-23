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

# Helper function to generate exit codes display for usage
print_exit_codes() {
    local var_name code desc_var description
    echo "Exit Codes:"
    for var_name in EXIT_SUCCESS ERROR_DEFAULT ERROR_USAGE ERROR_NO_INTERNET ERROR_ENV_FILE_MISSING; do
        code=${!var_name}
        desc_var="DESC_${var_name}"
        description=${!desc_var}
        printf "  %-6s%s\n" "$code" "$description"
    done
}