#!/usr/bin/env bash
# Posix-compliant script to make all scripts in the scripts directory (including subdirectories) executable
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"

# Makes every script in the scripts directory (including subdirectories) executable
set_script_permissions() {
    header "Setting script permissions"
    find "$HERE" -type f -name "*.sh" -exec chmod +x {} \;
    success "All scripts in ${HERE} are now executable"
}