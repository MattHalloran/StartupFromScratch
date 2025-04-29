#!/usr/bin/env bash
# Installs Caddy web server on Debian/Ubuntu and potentially other systems via helpers.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"

is_caddy_installed() {
    if command -v caddy &> /dev/null; then
        return 0
    else
        return 1
    fi
}

install_caddy() {
    if is_caddy_installed; then
        info "Caddy is already installed."
        caddy version
        return 0
    fi

    info "Attempting to install Caddy using system package manager..."

    # --- Debian/Ubuntu Specific Setup ---
    if command -v apt-get &> /dev/null; then
        info "Performing Debian/Ubuntu specific setup for Caddy repository..."
        # Ensure prerequisites are installed
        install_system_package "debian-keyring"
        install_system_package "debian-archive-keyring"
        install_system_package "apt-transport-https"
        install_system_package "curl"

        # Add Caddy GPG key
        maybe_run_sudo curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | maybe_run_sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        if [ $? -ne 0 ]; then 
            exit_with_error "Failed to add Caddy GPG key." "$ERROR_INSTALLATION_FAILED"
        fi

        # Add Caddy repository
        maybe_run_sudo curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | maybe_run_sudo tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null
        if [ $? -ne 0 ]; then 
            exit_with_error "Failed to add Caddy repository." "$ERROR_INSTALLATION_FAILED"
        fi

        # Update package list after adding repo
        system_update
    elif command -v brew &> /dev/null; then
        info "Using Homebrew (no specific pre-setup needed for Caddy)."
        # Potentially add steps for other package managers here if needed
    else
        warn "Unrecognized package manager for specific Caddy pre-setup. Proceeding with generic install."
    fi
    # --- End Specific Setup ---

    # Install Caddy using the generic helper
    install_system_package "caddy"

    if command -v caddy &> /dev/null; then
        success "Caddy installed successfully via package manager."
        caddy version
        # Enable service only if systemctl exists (common on Linux)
        if command -v systemctl &> /dev/null && command -v apt-get &> /dev/null; then # Check for apt too, as brew doesn't typically use systemctl this way
             maybe_run_sudo systemctl enable caddy
             info "Enabled Caddy systemd service."
        elif command -v brew &> /dev/null; then
             info "Homebrew manages services differently (e.g., brew services start caddy). Manual start might be needed if not done automatically."
        fi
    else
        exit_with_error "Caddy installation failed." "$ERROR_INSTALLATION_FAILED"
    fi
}

setup_reverse_proxy() {
    header "Setting up reverse proxy..."
    install_caddy
    # Determine domain: use DOMAIN env if set, otherwise extract from API_URL
    local target_domain=""
    if [[ -n "${DOMAIN:-}" ]]; then
        target_domain="$DOMAIN"
    elif [[ -n "${API_URL:-}" ]]; then
        # Extract hostname from API_URL (strip scheme and path)
        target_domain=$(echo "$API_URL" | sed -E 's#https?://([^/]+).*#\1#')
        info "Using domain from API_URL: $target_domain"
    else
        exit_with_error "Either DOMAIN or API_URL environment variable must be set for reverse proxy setup." "$ERROR_CONFIGURATION"
    fi
    # Determine port: use PORT env if set, otherwise default to 4000
    local proxy_port="${PORT:-4000}"
    # Start or reload the reverse proxy configuration for the application
    start_reverse_proxy "$target_domain" "$proxy_port"
}