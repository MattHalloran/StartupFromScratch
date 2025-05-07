#!/usr/bin/env bash
# Posix-compliant script to make all scripts executable
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPTS_DIR=$(cd "$HERE"/.. && pwd)
POSTGRES_ENTRYPOINT_DIR=$(cd "$HERE"/../../packages/postgres/entrypoint && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/logging.sh"

# Makes every script executable
set_script_permissions() {
    header "Setting script permissions"
    find "$SCRIPTS_DIR" -type f -name "*.sh" -exec chmod +x {} \;
    success "All scripts in ${SCRIPTS_DIR} are now executable"
    if [ -d "$POSTGRES_ENTRYPOINT_DIR" ]; then
        find "$POSTGRES_ENTRYPOINT_DIR" -type f -name "*.sh" -exec chmod +x {} \;
        success "Postgres entrypoint scripts in ${POSTGRES_ENTRYPOINT_DIR} are now executable"
    else
        warning "Postgres entrypoint directory not found: ${POSTGRES_ENTRYPOINT_DIR}"
    fi
}
