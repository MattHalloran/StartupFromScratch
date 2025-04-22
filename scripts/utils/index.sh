#!/bin/bash
# index.sh
# Sources all .sh scripts in this directory for easy single-line inclusion.
# Usage: source "/path/to/utils/index.sh"

# Determine this script's directory
UTILS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Name of this index script
CURRENT_SCRIPT="$(basename "${BASH_SOURCE[0]}")"

# Source each .sh file in this directory, excluding this index file
for util_file in "${UTILS_DIR}"/*.sh; do
    if [[ "$(basename "${util_file}")" != "${CURRENT_SCRIPT}" ]]; then
        source "${util_file}"
    fi
done 