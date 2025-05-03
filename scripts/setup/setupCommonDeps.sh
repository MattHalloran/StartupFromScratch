#!/usr/bin/env bash
# shellcheck disable=SC2148

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"

# --- Common Dependency Setup Functions ---

# Checks if curl is installed, attempts to install if missing.
check_and_install_curl() {
    info "Checking for curl..."
    if check_command_exists "curl"; then
        success "curl is already installed."
        return 0
    fi

    warning "curl not found. Attempting installation..."
    install_system_package "curl"

    if check_command_exists "curl"; then
        success "curl installed successfully."
        return 0
    else
        error "Failed to install curl. Please install it manually using your system package manager (e.g., 'sudo apt install curl' or 'brew install curl')."
        exit "${ERROR_DEPENDENCY_MISSING:-5}"
    fi
}

# Checks if jq is installed, attempts to install if missing.
check_and_install_jq() {
    info "Checking for jq..."
    if check_command_exists "jq"; then
        success "jq is already installed."
        return 0
    fi

    warning "jq not found. Attempting installation..."
    install_system_package "jq"

    if check_command_exists "jq"; then
        success "jq installed successfully."
        return 0
    else
        error "Failed to install jq. Please install it manually using your system package manager (e.g., 'sudo apt install jq' or 'brew install jq'). See https://stedolan.github.io/jq/download/"
        exit "${ERROR_DEPENDENCY_MISSING:-5}"
    fi
}

# Main function to check and install common dependencies like curl and jq.
setup_common_deps() {
    header "⚙️ Checking common dependencies (curl, jq)..."
    check_and_install_curl
    check_and_install_jq
    success "✅ Common dependencies checked/installed."
    return 0
} 