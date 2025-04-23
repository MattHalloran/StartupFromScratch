#!/bin/bash
# Posix-compliant script to setup the project for native Linux development/production
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../../utils/index.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/setupPnpm.sh"

setup_native_linux() {
    header "Setting up native Linux development/production..."

    # Setup pnpm and generate Prisma client
    setup_pnpm
}
