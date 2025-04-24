#!/usr/bin/env bash
# Posix-compliant script to clean up volumes, caches, packages, and other build artifacts. 
# When complete, you should be able to set up the project from a clean slate.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"

# Clear node_modules at the root and in all project subdirectories without descending into them
clear_node_modules() {
    header "Deleting all node_modules directories"
    # Prune node_modules directories to avoid find recursing into them after deletion
    find "${HERE}/../.." -maxdepth 4 -type d -name "node_modules" -prune -exec rm -rf {} +
}

# Peforms all cleanup steps
clean() {
    clear_node_modules
}

