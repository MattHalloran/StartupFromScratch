#!/usr/bin/env bash
# Posix-compliant script to check if host has internet access
set -euo pipefail

SETUP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/log.sh"
# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/exit_codes.sh"

# Check if host has internet access. Exits with error if no access.
internet::check_connection() {
    log::header "Checking host internet access..."
    if ping -c 1 google.com &>/dev/null; then
        log::success "Host internet access: OK"
    else
        log::error "Host internet access: FAILED"
        exit "${ERROR_NO_INTERNET:-5}"
    fi
}