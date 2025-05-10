#!/usr/bin/env bash
# Posix-compliant script to make all scripts executable
set -euo pipefail

SETUP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/locations.sh"
# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/logging.sh"

# Makes all scripts in a directory (recursively) executable
make_scripts_executable() {
    header "Making scripts in ${1} executable"
    if [ -d "$1" ]; then
        find "$1" -type f -name "*.sh" -exec chmod +x {} \;
        success "All scripts in ${1} are now executable"
    else
        warning "Directory not found: ${1}"
    fi
}

# Makes every script executable
set_script_permissions() {
    make_scripts_executable "$SCRIPTS_DIR"
    make_scripts_executable "$POSTGRES_ENTRYPOINT_DIR"
}
