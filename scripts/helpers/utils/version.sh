#!/usr/bin/env bash
# Handles getting and setting the version of the project.
set -euo pipefail

UTILS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${UTILS_DIR}/log.sh"
# shellcheck disable=SC1091
source "${UTILS_DIR}/var.sh"

# Finds the project version using the root package.json file.
version::get_project_version() {
    # Extract the current version number from the package.json file
    local version
    version=$(cat ${var_ROOT_DIR}/package.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
    echo "$version"
}

# Updates the project version in all package.json files.
version::set_package_json_version() {
    local target_version="$1"
    if [ -z "$target_version" ]; then
        log::error "No version supplied"
        exit "$ERROR_USAGE"
    fi

    # Update all package.json files in the project
    # Use -i.bak for wider compatibility (GNU vs BSD sed) and delete .bak files afterwards.
    # Make regex more robust to spacing around version field.
    find "${var_ROOT_DIR}/packages" -name package.json -exec sed -i.bak "s/\\"version\\":[[:space:]]*\\"$version\\"/\\"version\\": \\"$target_version\\"/g" {} +
    find "${var_ROOT_DIR}/packages" -name package.json.bak -delete
    # Update root package.json file too
    sed -i.bak "s/\\"version\\":[[:space:]]*\\"$version\\"/\\"version\\": \\"$target_version\\"/g" "${var_ROOT_DIR}/package.json" && rm "${var_ROOT_DIR}/package.json.bak"
}

# Updates the appVersion in k8s/chart/Chart.yaml.
version::set_helm_chart_app_version() {
    local target_version="$1"
    if [ -z "$target_version" ]; then
        log::error "No version supplied"
        exit "$ERROR_USAGE"
    fi

    local chart_file="${var_ROOT_DIR}/k8s/chart/Chart.yaml"
    if [ ! -f "$chart_file" ]; then
        log::error "Chart.yaml not found at $chart_file"
        exit "$ERROR_FATAL"
    fi

    # Use sed to replace the appVersion value, regardless of the current value.
    # Matches 'appVersion: "any.version.here"' and replaces 'any.version.here' with target_version.
    # This preserves spaces between 'appVersion:' and the opening quote.
    # Use -i.bak and rm .bak for wider compatibility (GNU vs BSD sed)
    sed -i.bak "s/^\\(appVersion:[[:space:]]*\\"\\\\)[^\\"]*\\(\\"\\\\)/\\1$target_version\\2/" "$chart_file" && rm "${chart_file}.bak"
    
    # Check if the update was successful using extended regex for flexibility with spacing.
    if ! grep -Eq "^appVersion:[[:space:]]*\"$target_version\"" "$chart_file"; then
        log::error "Failed to update appVersion in $chart_file to $target_version"
        exit "$ERROR_FATAL"
    fi
}

# Updates the service tags in k8s/chart/values-prod.yaml.
version::set_values_prod_service_tags() {
    local target_version="$1"
    if [ -z "$target_version" ]; then
        log::error "No version supplied"
        exit "$ERROR_USAGE"
    fi

    local values_file="${var_ROOT_DIR}/k8s/chart/values-prod.yaml"
    if [ ! -f "$values_file" ]; then
        log::error "values-prod.yaml not found at $values_file"
        exit "$ERROR_FATAL"
    fi

    log::info "Updating service tags in $values_file to $target_version"

    # Update UI service tag
    # Range: from '  ui:' up to (but not including) '  server:'
    # Action: find '    tag: "..."' and replace "..." with target_version
    # Use -i.bak and rm .bak for wider compatibility (GNU vs BSD sed)
    sed -i.bak '/^[[:space:]]\{2\}ui:/,/^[[:space:]]\{2\}server:/{ /^[[:space:]]\{4\}tag:[[:space:]]*\\"[^\\"]*\\"/s/\\"[^\\"]*\\"/\\"'$target_version'\\"/; }' "$values_file" && rm "${values_file}.bak"
    local expected_ui_tag_line="    tag: \\"$target_version\\""
    if ! sed -n '/^[[:space:]]\{2\}ui:/,/^[[:space:]]\{2\}server:/p' "$values_file" | grep -Fq "$expected_ui_tag_line"; then
        log::error "Failed to update UI tag to $target_version in $values_file. Expected line: '$expected_ui_tag_line'"
        local ui_block_content=$(sed -n '/^[[:space:]]\{2\}ui:/,/^[[:space:]]\{2\}server:/p' "$values_file")
        log::error "Relevant UI block content in $values_file:\n$ui_block_content"
        exit "$ERROR_FATAL"
    fi

    # Update Server service tag
    # Range: from '  server:' up to (but not including) '  jobs:'
    # Use -i.bak and rm .bak for wider compatibility (GNU vs BSD sed)
    sed -i.bak '/^[[:space:]]\{2\}server:/,/^[[:space:]]\{2\}jobs:/{ /^[[:space:]]\{4\}tag:[[:space:]]*\\"[^\\"]*\\"/s/\\"[^\\"]*\\"/\\"'$target_version'\\"/; }' "$values_file" && rm "${values_file}.bak"
    local expected_server_tag_line="    tag: \\"$target_version\\""
    if ! sed -n '/^[[:space:]]\{2\}server:/,/^[[:space:]]\{2\}jobs:/p' "$values_file" | grep -Fq "$expected_server_tag_line"; then
        log::error "Failed to update Server tag to $target_version in $values_file. Expected line: '$expected_server_tag_line'"
        local server_block_content=$(sed -n '/^[[:space:]]\{2\}server:/,/^[[:space:]]\{2\}jobs:/p' "$values_file")
        log::error "Relevant Server block content in $values_file:\n$server_block_content"
        exit "$ERROR_FATAL"
    fi

    # Update Jobs service tag
    # Range: from '  jobs:' up to (but not including) '  nsfwDetector:'
    # Use -i.bak and rm .bak for wider compatibility (GNU vs BSD sed)
    sed -i.bak '/^[[:space:]]\{2\}jobs:/,/^[[:space:]]\{2\}nsfwDetector:/{ /^[[:space:]]\{4\}tag:[[:space:]]*\\"[^\\"]*\\"/s/\\"[^\\"]*\\"/\\"'$target_version'\\"/; }' "$values_file" && rm "${values_file}.bak"
    local expected_jobs_tag_line="    tag: \\"$target_version\\""
    if ! sed -n '/^[[:space:]]\{2\}jobs:/,/^[[:space:]]\{2\}nsfwDetector:/p' "$values_file" | grep -Fq "$expected_jobs_tag_line"; then
        log::error "Failed to update Jobs tag to $target_version in $values_file. Expected line: '$expected_jobs_tag_line'"
        local jobs_block_content=$(sed -n '/^[[:space:]]\{2\}jobs:/,/^[[:space:]]\{2\}nsfwDetector:/p' "$values_file")
        log::error "Relevant Jobs block content in $values_file:\n$jobs_block_content"
        exit "$ERROR_FATAL"
    fi

    log::info "Service tags in $values_file updated successfully to $target_version."
}

# Updates all package.json files and the helm chart appVersion.
version::set_project_version() {
    local target_version="$1"
    if [ -z "$target_version" ]; then
        log::error "No version supplied"
        exit "$ERROR_USAGE"
    fi
    
    local version
    version=$(version::get_project_version)
    if [ "$version" != "$target_version" ]; then
        log::info "Updating project version to $target_version"
        version::set_package_json_version "$target_version"
        version::set_helm_chart_app_version "$target_version"
        version::set_values_prod_service_tags "$target_version"
    else
        log::info "Version $target_version is already set, skipping"
    fi
}
