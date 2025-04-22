#!/bin/bash
# Posix-compliant script to clean up volumes, caches, packages, and other build artifacts. 
# When complete, you should be able to set up the project from a clean slate.

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${HERE}/../utils/index.sh"

# Clear node_modules at the root and in all project subdirectories
clear_node_modules() {
    header "Deleting all node_modules directories"
    find "${HERE}/../.." -maxdepth 4 -name "node_modules" -type d -exec rm -rf {} \;
}

# Peforms all cleanup steps
clean() {
    clear_node_modules
}

clean
