#!/bin/bash
# Posix-compliant script to setup the project for native Linux development/production

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${HERE}/../utils/index.sh"

setup_native_linux() {
    header "Setting up native Linux development/production..."
}
