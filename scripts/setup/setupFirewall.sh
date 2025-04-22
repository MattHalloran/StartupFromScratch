#!/bin/bash
# Posix-compliant script to setup the firewall

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${HERE}/../utils/index.sh"

# Check if host has internet access. Exits with error if no access.
setup_firewall() {
    header "🔥🧱 Setting up firewall in $ENVIRONMENT environment..."
    
    # 1) Enable UFW only if not already active
    if ! sudo ufw status verbose | grep -q "^Status: active"; then
        info "Enabling UFW"
        sudo ufw --force enable
    else
        info "UFW already active"
    fi

    # 2) Apply default policies only if they differ
    defaults=$(sudo ufw status verbose | grep "^Default:")
    # want: "Default: deny (incoming), allow (outgoing)"
    if ! echo "$defaults" | grep -q "deny (incoming).*allow (outgoing)"; then
        info "Setting default policies"
        sudo ufw default allow outgoing
        sudo ufw default deny incoming
    else
        info "Default policies already set"
    fi

    # 3) Helper: only open a port if not already allowed
    ensure_allow() {
        local port_proto="$1/$2"
        if ! sudo ufw status | grep -qw "$port_proto"; then
            info "Allowing $port_proto"
            sudo ufw allow "$port_proto"
        fi
    }

    # Always allow HTTP, HTTPS, SSH
    ensure_allow 80  tcp
    ensure_allow 443 tcp
    if ! sudo ufw status | grep -qw "OpenSSH"; then
        info "Allowing SSH"
        sudo ufw allow ssh
    fi

    # Dev mode: open app ports
    if [ "$ENVIRONMENT" = "development" ]; then
        ensure_allow 3000 tcp
        ensure_allow 4000 tcp
    fi

    # 4) Reload sysctl (cheap) and UFW (cheap if no changes)
    sudo sysctl -p >/dev/null 2>&1
    sudo ufw reload  >/dev/null 2>&1

    success "Firewall setup complete"
}