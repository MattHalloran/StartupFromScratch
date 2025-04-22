#!/bin/bash
# Posix-compliant script to check if host has internet access

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${HERE}/../utils/index.sh"

# Check if host has internet access. Exits with error if no access.
check_internet() {
    header "Checking host internet access..."
    if ping -c 1 google.com &>/dev/null; then
        success "Host internet access: OK"
    else
        error "Host internet access: FAILED"
        exit ${ERROR_NO_INTERNET}
    fi
}