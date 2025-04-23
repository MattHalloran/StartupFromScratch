#!/bin/bash
# Posix-compliant script to setup the project for native Windows development/production
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../../utils/index.sh"

setup_native_win() {
    header "Setting up native Windows development/production..."
}
