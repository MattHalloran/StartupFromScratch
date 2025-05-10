#!/usr/bin/env bash
# shellcheck disable=SC2148

SETUP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/flow.sh"
# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/log.sh"
# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/system.sh"

# --- Vault Client Dependency Setup Functions ---

# Checks if the HashiCorp Vault CLI ('vault') is installed.
# If not, prints instructions and exits.
setup_vault::check_cli() {
    log::info "Checking for Vault CLI..."
    if system::is_command "vault"; then
        log::success "Vault CLI is already installed."
        return 0
    fi

    # Vault CLI installation is typically manual (downloading binary)
    # Attempting auto-install via package managers is unreliable
    log::error "HashiCorp Vault CLI ('vault') not found. Please install it manually from https://developer.hashicorp.com/vault/downloads and ensure it's in your system PATH."
    exit "${ERROR_DEPENDENCY_MISSING:-5}"
}

# Main function to check for the Vault CLI.
setup_vault::check_deps() {
    log::header "⚙️ Checking Vault client dependencies..."
    setup_vault::check_cli
    log::success "✅ Vault client dependencies checked."
    return 0
} 