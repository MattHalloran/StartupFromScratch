#!/bin/bash
# Posix-compliant script to setup the project for native Mac development/production

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${HERE}/../../utils/index.sh"

setup_native_mac() {
    header "Setting up native Mac development/production..."
}
