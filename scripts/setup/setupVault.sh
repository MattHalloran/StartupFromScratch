#!/usr/bin/env bash
# shellcheck disable=SC2148

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"

# --- Vault Client Dependency Setup Functions ---

# Checks if the HashiCorp Vault CLI ('vault') is installed.
# If not, prints instructions and exits.
check_vault_cli() {
    info "Checking for Vault CLI..."
    if check_command_exists "vault"; then
        success "Vault CLI is already installed."
        return 0
    fi

    # Vault CLI installation is typically manual (downloading binary)
    # Attempting auto-install via package managers is unreliable
    error "HashiCorp Vault CLI ('vault') not found. Please install it manually from https://developer.hashicorp.com/vault/downloads and ensure it's in your system PATH."
    exit "${ERROR_DEPENDENCY_MISSING:-5}"
}

# Main function to check for the Vault CLI.
setup_vault_client_deps() {
    header "⚙️ Checking Vault client dependencies..."
    check_vault_cli
    success "✅ Vault client dependencies checked."
    return 0
} 