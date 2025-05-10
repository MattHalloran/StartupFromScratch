#!/usr/bin/env bash
# Posix-compliant script to make all scripts executable
set -euo pipefail

SETUP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/locations.sh"
# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/log.sh"

# Makes all scripts in a directory (recursively) executable
permissions::make_files_in_dir_executable() {
    log::header "Making scripts in ${1} executable"
    if [ -d "$1" ]; then
        find "$1" -type f -name "*.sh" -exec chmod +x {} \;
        log::success "All scripts in ${1} are now executable"
    else
        log::warning "Directory not found: ${1}"
    fi
}

# Makes every script executable
permissions::make_scripts_executable() {
    permissions::make_files_in_dir_executable "$SCRIPTS_DIR"
    permissions::make_files_in_dir_executable "$POSTGRES_ENTRYPOINT_DIR"
}
