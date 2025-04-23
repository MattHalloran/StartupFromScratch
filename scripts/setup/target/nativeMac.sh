#!/bin/bash
# Posix-compliant script to setup the project for native Mac development/production
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../../utils/index.sh"

setup_native_mac() {
    header "Setting up native Mac development/production..."
}
