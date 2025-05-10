#!/usr/bin/env bash
# Posix-compliant script to setup the project for native Linux development/production
set -euo pipefail

SETUP_TARGET_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${SETUP_TARGET_DIR}/../../utils/log.sh"
# shellcheck disable=SC1091
source "${SETUP_TARGET_DIR}/../setupPnpm.sh"

setup_native_linux() {
    log::header "Setting up native Linux development/production..."

    # Setup pnpm and generate Prisma client
    setup_pnpm
}
