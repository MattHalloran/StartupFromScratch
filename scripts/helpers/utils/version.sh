#!/usr/bin/env bash
# Handles getting and setting the version of the project.
set -euo pipefail

UTILS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${UTILS_DIR}/var.sh"

# Finds the project version using the root package.json file.
get_project_version() {
    # Extract the current version number from the package.json file
    local version
    version=$(cat ${var_ROOT_DIR}/package.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
    echo "$version"
}

# Updates all package.json files in the project with the given version.
set_project_version() {
    local target_version="$1"
    if [ -z "$target_version" ]; then
        log::error "No version supplied"
        exit "$ERROR_USAGE"
    fi
    
    local version
    version=$(get_project_version)
    if [ "$version" != "$target_version" ]; then
        log::info "Updating project version to $target_version"
        # Update all package.json files in the project
        find ${var_ROOT_DIR}/packages -name package.json -exec sed -i '' "s/\"version\": \"$version\"/\"version\": \"$target_version\"/g" {} +
        # Update root package.json file too
        sed -i '' "s/\"version\": \"$version\"/\"version\": \"$target_version\"/g" ${var_ROOT_DIR}/package.json
    else
        log::info "Version $target_version is already set, skipping"
    fi
}