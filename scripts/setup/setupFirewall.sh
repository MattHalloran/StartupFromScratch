#!/usr/bin/env bash
# Posix-compliant script to setup the firewall
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"

# Check if host has internet access. Exits with error if no access.
setup_firewall() {
    header "🔥🧱 Setting up firewall in $ENVIRONMENT environment..."
    
    # Track if any changes were made
    local changes_made=false

    # Cache verbose status for initial checks
    local status_verbose
    status_verbose=$(sudo ufw status verbose)

    # 1) Enable UFW only if not already active
    if echo "$status_verbose" | grep -q "^Status: active"; then
        info "UFW already active"
    else
        info "Enabling UFW"
        sudo ufw --force enable
        changes_made=true
        # Update status after enabling
        status_verbose=$(sudo ufw status verbose)
    fi

    # 2) Apply default policies only if they differ
    local defaults
    defaults=$(echo "$status_verbose" | grep "^Default:")
    if echo "$defaults" | grep -q "deny (incoming).*allow (outgoing)"; then
        info "Default policies already set"
    else
        info "Setting default policies"
        sudo ufw default allow outgoing
        sudo ufw default deny incoming
        changes_made=true
    fi

    # 3) Only open required ports using a loop to minimize status calls
    local ports=("80/tcp" "443/tcp" "22/tcp")
    if [ "$ENVIRONMENT" = "development" ]; then
        ports+=("3000/tcp" "4000/tcp")
    fi

    # Cache plain status for rule checks
    local status_plain
    status_plain=$(sudo ufw status)

    for port_proto in "${ports[@]}"; do
        if echo "$status_plain" | grep -qw "$port_proto"; then
            info "Rule for $port_proto already exists"
        else
            info "Allowing $port_proto"
            sudo ufw allow "$port_proto"
            changes_made=true
        fi
    done

    # 4) Reload sysctl and UFW only if changes were made
    if $changes_made; then
        info "Reloading sysctl and UFW"
        sudo sysctl -p >/dev/null 2>&1
        sudo ufw reload >/dev/null 2>&1
    else
        info "No firewall changes needed; skipping reload"
    fi

    success "Firewall setup complete"
}