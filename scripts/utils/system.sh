#!/usr/bin/env bash
# system.sh - Cross-platform package manager helpers
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/logging.sh"

# Default timeout for system installs (in seconds)
SYSTEM_INSTALL_TIMEOUT=${SYSTEM_INSTALL_TIMEOUT:-60}

# Install a package by selecting the correct package manager
install_system_package() {
    local pkg="$1"
    header "📦 Installing system package: $pkg"
    if command -v apt-get >/dev/null 2>&1; then
        # If we can sudo, prefix apt commands; otherwise run as current user
        local apt_cmd="apt-get"
        if can_run_sudo; then
            apt_cmd="sudo apt-get"
        else
            info "No sudo available, running apt-get as current user"
        fi
        # Update package list and install
        timeout --kill-after=10s "${SYSTEM_INSTALL_TIMEOUT}"s $apt_cmd update -qq
        timeout --kill-after=10s "${SYSTEM_INSTALL_TIMEOUT}"s $apt_cmd install -y -qq --no-install-recommends "$pkg"
        success "${pkg} installed via apt-get"
    elif command -v brew >/dev/null 2>&1; then
        # Perform Homebrew install with a timeout to prevent hangs
        timeout --kill-after=10s "${SYSTEM_INSTALL_TIMEOUT}"s brew install "$pkg"
        success "${pkg} installed via Homebrew"
    else
        error "No supported package manager found to install $pkg"
    fi
}

# Update package lists
system_update() {
    header "🔄 Updating system package lists"
    if command -v apt-get >/dev/null 2>&1; then
        # If we can sudo, prefix apt commands; otherwise run as current user
        local update_cmd="apt-get"
        if can_run_sudo; then
            update_cmd="sudo apt-get"
        else
            info "No sudo available, running apt-get update as current user"
        fi
        $update_cmd update
        success "apt-get update complete"
    elif command -v brew >/dev/null 2>&1; then
        brew update
        success "Homebrew update complete"
    else
        error "No supported package manager found for update"
    fi
}

# Upgrade installed packages
system_upgrade() {
    header "⬆️ Upgrading system packages"
    if command -v apt-get >/dev/null 2>&1; then
        # If we can sudo, prefix apt commands; otherwise run as current user
        local upgrade_cmd="apt-get"
        if can_run_sudo; then
            upgrade_cmd="sudo apt-get"
        else
            info "No sudo available, running apt-get upgrade as current user"
        fi
        $upgrade_cmd -y upgrade
        success "apt-get upgrade complete"
    elif command -v brew >/dev/null 2>&1; then
        brew upgrade
        success "Homebrew upgrade complete"
    else
        error "No supported package manager found for upgrade"
    fi
} 

# Limits the number of system update calls
should_run_system_update() {
    if command -v apt-get >/dev/null 2>&1; then
        # Use apt list timestamp to throttle updates
        local last_update
        last_update=$(stat -c %Y /var/lib/apt/lists/)
        local current_time
        current_time=$(date +%s)
        local update_interval=$((24 * 60 * 60))
        if ((current_time - last_update > update_interval)); then
            return 0
        else
            return 1
        fi
    elif command -v brew >/dev/null 2>&1; then
        # Always run brew update
        return 0
    else
        # Unknown package manager: skip
        return 1
    fi
}

# Limit the number of system upgrade calls
should_run_system_upgrade() {
    if command -v apt-get >/dev/null 2>&1; then
        # Use dpkg status timestamp to throttle upgrades
        local last_upgrade
        last_upgrade=$(stat -c %Y /var/lib/dpkg/status)
        local current_time
        current_time=$(date +%s)
        local upgrade_interval=$((7 * 24 * 60 * 60))
        if ((current_time - last_upgrade > upgrade_interval)); then
            return 0
        else
            return 1
        fi
    elif command -v brew >/dev/null 2>&1; then
        # Always run brew upgrade
        return 0
    else
        # Unknown package manager: skip
        return 1
    fi
}

run_system_update_and_upgrade() {
    if should_run_system_update; then
        system_update
    else
        info "Skipping system update - last update was less than 24 hours ago"
    fi
    if should_run_system_upgrade; then
        system_upgrade
    else
        info "Skipping system upgrade - last upgrade was less than 1 week ago"
    fi
}

# Purges apt update notifier, which can cause hangs on some systems
purge_apt_update_notifier() {
    sudo apt purge update-notifier update-notifier-common
}
