#!/usr/bin/env bash
# system.sh - Cross-platform package manager helpers
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/logging.sh"
# shellcheck disable=SC1091
source "${HERE}/../utils/flow.sh"

# Default timeout for system installs (in seconds)
SYSTEM_INSTALL_TIMEOUT=${SYSTEM_INSTALL_TIMEOUT:-420}

detect_pm() {
    if   command -v apt-get  >/dev/null; then echo "apt-get"
    elif command -v dnf      >/dev/null; then echo "dnf"
    elif command -v yum      >/dev/null; then echo "yum"
    elif command -v pacman   >/dev/null; then echo "pacman"
    elif command -v apk      >/dev/null; then echo "apk"
    elif command -v brew     >/dev/null; then echo "brew"
    else
        error "Unsupported pkg manager; please install dependencies manually."
        exit 1
    fi
}

# Given a command name, return the real package to install on this distro.
get_package_name() {
    local cmd="$1"
    local pm
    pm=$(detect_pm)
    
    case "$cmd" in
        # coreutils commands
        nproc|mkdir|sed|grep|awk)
            case "$pm" in
                apt-get)   echo "coreutils" ;;
                dnf|yum)   echo "coreutils" ;;
                pacman)    echo "coreutils" ;;
                apk)       echo "coreutils" ;;    # Alpine has coreutils
                brew)      echo "coreutils" ;;    # Homebrew coreutils
            esac
            ;;
        free)
            case "$pm" in
              apt-get)   echo "procps" ;;         # Debian/Ubuntu
              dnf|yum)   echo "procps-ng" ;;      # Fedora/RHEL/CentOS
              pacman)    echo "procps-ng" ;;      # Arch
              apk)       echo "procps" ;;
              brew)      echo "procps" ;;         # Homebrew? usually not needed
            esac
            ;;
        *)
            # fallback: assume the package has the same name
            echo "$cmd"
            ;;
    esac
}

install_pkg() {
    local pkg="$1"
    local pm prefix
  
    header "📦 Installing system package $pkg as $(get_package_name $pkg)"
    pkg=$(get_package_name $pkg)
    pm=$(detect_pm)
  
    # Brew never needs sudo; others only if allowed
    if [[ "$pm" == "brew" ]]; then
        prefix=""
    elif can_run_sudo; then
        prefix="sudo"
    else
        prefix=""
        warning "No sudo available; running $pm commands as user"
    fi
  
    case "$pm" in
        apt-get)
            # prevent hanging on apt
            timeout --kill-after=10s "${SYSTEM_INSTALL_TIMEOUT}"s ${prefix} apt-get update -qq
            timeout --kill-after=10s "${SYSTEM_INSTALL_TIMEOUT}"s ${prefix} apt-get install -y -qq --no-install-recommends "$pkg"
            ;;
        dnf)
            ${prefix} dnf install -y "$pkg"
            ;;
        yum)
            ${prefix} yum install -y "$pkg"
            ;;
        pacman)
            ${prefix} pacman -Syu --noconfirm "$pkg"
            ;;
        apk)
            ${prefix} apk update
            ${prefix} apk add --no-cache "$pkg"
          ;;
        brew)
            brew install "$pkg"
            ;;
        *)
            error "Unsupported pkg manager: $pm"
            exit 1
            ;;
    esac
    
    success "Installed $pkg via $pm"
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
    if command -v apt-get &> /dev/null; then
        info "Purging apt update-notifier packages (if present)..."
        maybe_run_sudo apt-get purge -y update-notifier update-notifier-common || info "Update notifier not present or already purged."
        success "Finished attempting to purge update-notifier."
    else
        info "Not an apt-based system, skipping update-notifier purge."
    fi
}

check_and_install() {
    local cmd="$1"
    info "Checking for $cmd..."
    if check_command_exists "$cmd"; then
        success "$cmd is already installed."
        return 0
    fi
  
    warning "$cmd not found. Installing…"
    install_pkg "$cmd"
  
    if check_command_exists "$cmd"; then
        success "$cmd installed successfully."
    else
        error "Could not install $cmd—please install it manually."
        exit "${ERROR_DEPENDENCY_MISSING}"
    fi
}