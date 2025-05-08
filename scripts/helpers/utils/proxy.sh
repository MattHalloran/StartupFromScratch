#!/usr/bin/env bash
# Installs Caddy web server on Debian/Ubuntu and potentially other systems via helpers.
set -euo pipefail

UTILS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${UTILS_DIR}/logging.sh"
# shellcheck disable=SC1091
source "${UTILS_DIR}/flow.sh"
# shellcheck disable=SC1091
source "${UTILS_DIR}/reverseProxy.sh"
# shellcheck disable=SC1091
source "${UTILS_DIR}/system.sh"

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
        install_pkg "debian-keyring"
        install_pkg "debian-archive-keyring"
        install_pkg "apt-transport-https"
        install_pkg "curl"

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
    install_pkg "caddy"

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
    local proxy_port="${PORT_SERVER:-5329}"
    local ui_port="${PORT_UI:-3000}"
    # Include do-origin alias for crawler requests
    local alias_domain="do-origin.${target_domain}"
    info "Including alias domain for crawler: ${alias_domain}"
    # Append alias so Caddy will request a cert for both hosts
    target_domain="${target_domain} ${alias_domain}"
    # Start or reload the reverse proxy configuration for the application
    start_reverse_proxy "${target_domain}" "${proxy_port}" "${ui_port}"
}