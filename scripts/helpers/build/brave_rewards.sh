#!/usr/bin/env bash
# This script handles the creation of the Brave Rewards verification file.

BUILD_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${BUILD_DIR}/../utils/log.sh"
# shellcheck disable=SC1091
source "${BUILD_DIR}/../utils/var.sh"

brave_rewards::create_verification_file() {
    log::info "Checking for Brave Rewards verification setup..."

    if [ -z "${BRAVE_REWARDS_TOKEN-}" ]; then
        log::info "BRAVE_REWARDS_TOKEN is not set. Skipping creation of .well-known/brave-rewards-verification.txt file."
        return 0
    fi

    if [ -z "${BRAVE_REWARDS_DOMAIN-}" ]; then
        log::warning "BRAVE_REWARDS_TOKEN is set, but BRAVE_REWARDS_DOMAIN is not. Cannot create brave-rewards-verification.txt without the domain."
        # Optionally, could return 1 to indicate a problem if this is considered an error state.
        return 0 # For now, just skip.
    fi

    log::info "Creating .well-known/brave-rewards-verification.txt file..."

    local well_known_dir="${var_ROOT_DIR}/packages/ui/dist/.well-known"
    local verification_file="${well_known_dir}/brave-rewards-verification.txt"

    # Ensure the packages/ui/dist directory exists (should be created by build_packages)
    if [ ! -d "${var_ROOT_DIR}/packages/ui/dist" ]; then
        log::error "Directory ${var_ROOT_DIR}/packages/ui/dist not found. Cannot create Brave Rewards file."
        log::error "This usually means 'build_packages' did not run or failed."
        return 1
    fi

    if ! mkdir -p "${well_known_dir}"; then
        log::error "Failed to create directory ${well_known_dir}."
        return 1
    fi

    # Create the verification file
    # Using printf for potentially better handling of newlines and special characters, though echo is fine here.
    # The file content has an intentional blank line after the first line.
    if printf "This is a Brave Rewards publisher verification file.\n\nDomain: %s\nToken: %s\n" "${BRAVE_REWARDS_DOMAIN}" "${BRAVE_REWARDS_TOKEN}" > "${verification_file}"; then
        log::success "Successfully created ${verification_file}"
    else
        log::error "Failed to create ${verification_file}"
        return 1
    fi

    return 0
} 