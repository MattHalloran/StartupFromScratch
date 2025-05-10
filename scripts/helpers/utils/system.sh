#!/usr/bin/env bash
# system.sh - Cross-platform package manager helpers
set -euo pipefail

UTILS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${UTILS_DIR}/exit_codes.sh"
# shellcheck disable=SC1091
source "${UTILS_DIR}/log.sh"
# shellcheck disable=SC1091
source "${UTILS_DIR}/flow.sh"

# Default timeout for system installs (in seconds)
SYSTEM_INSTALL_TIMEOUT=${SYSTEM_INSTALL_TIMEOUT:-420}

system::is_command() {
    # Using 'command -v' is generally preferred and more portable than 'which'
    command -v "$1" >/dev/null 2>&1
}

system::assert_command() {
    local command="$1"
    local error_message="${2:-Command $command not found}"
    if ! system::is_command "$command"; then
        log::error "$error_message"
        exit "${ERROR_COMMAND_NOT_FOUND}"
    fi
}

system::detect_pm() {
    if   system::is_command "apt-get"; then echo "apt-get"
    elif system::is_command "dnf"; then echo "dnf"
    elif system::is_command "yum"; then echo "yum"
    elif system::is_command "pacman"; then echo "pacman"
    elif system::is_command "apk"; then echo "apk"
    elif system::is_command "brew"; then echo "brew"
    else
        log::error "Unsupported pkg manager; please install dependencies manually."
        exit 1
    fi
}

# Given a command name, return the real package to install on this distro.
system::get_package_name() {
    local cmd="$1"
    local pm
    pm=$(system::detect_pm)
    
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

system::install_pkg() {
    local pkg="$1"
    local pm prefix
  
    log::header "📦 Installing system package $pkg as $(system::get_package_name $pkg)"
    pkg=$(system::get_package_name $pkg)
    pm=$(system::detect_pm)
  
    # Brew never needs sudo; others only if allowed
    if [[ "$pm" == "brew" ]]; then
        prefix=""
    elif flow::can_run_sudo; then
        prefix="sudo"
    else
        prefix=""
        log::warning "No sudo available; running $pm commands as user"
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
            log::error "Unsupported pkg manager: $pm"
            exit 1
            ;;
    esac
    
    log::success "Installed $pkg via $pm"
}

# Update package lists
system::update() {
    log::header "🔄 Updating system package lists"
    if system::is_command "apt-get"; then
        # If we can sudo, prefix apt commands; otherwise run as current user
        local update_cmd="apt-get"
        if flow::can_run_sudo; then
            update_cmd="sudo apt-get"
        else
            log::info "No sudo available, running apt-get update as current user"
        fi
        $update_cmd update
        log::success "apt-get update complete"
    elif system::is_command "brew"; then
        brew update
        log::success "Homebrew update complete"
    else
        log::error "No supported package manager found for update"
    fi
}

# Upgrade installed packages
system::upgrade() {
    log::header "⬆️ Upgrading system packages"
    if system::is_command "apt-get"; then
        # If we can sudo, prefix apt commands; otherwise run as current user
        local upgrade_cmd="apt-get"
        if flow::can_run_sudo; then
            upgrade_cmd="sudo apt-get"
        else
            log::info "No sudo available, running apt-get upgrade as current user"
        fi
        $upgrade_cmd -y upgrade
        log::success "apt-get upgrade complete"
    elif system::is_command "brew"; then
        brew upgrade
        log::success "Homebrew upgrade complete"
    else
        log::error "No supported package manager found for upgrade"
    fi
} 

# Limits the number of system update calls
system::should_run_update() {
    if system::is_command "apt-get"; then
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
    elif system::is_command "brew"; then
        # Always run brew update
        return 0
    else
        # Unknown package manager: skip
        return 1
    fi
}

# Limit the number of system upgrade calls
system::should_run_upgrade() {
    if system::is_command "apt-get"; then
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
    elif system::is_command "brew"; then
        # Always run brew upgrade
        return 0
    else
        # Unknown package manager: skip
        return 1
    fi
}

system::update_and_upgrade() {
    if system::should_run_update; then
        system::update
    else
        log::info "Skipping system update - last update was less than 24 hours ago"
    fi
    if system::should_run_upgrade; then
        system::upgrade
    else
        log::info "Skipping system upgrade - last upgrade was less than 1 week ago"
    fi
}

# Purges apt update notifier, which can cause hangs on some systems
system::purge_apt_update_notifier() {
    if system::is_command "apt-get"; then
        log::info "Purging apt update-notifier packages (if present)..."
        flow::maybe_run_sudo apt-get purge -y update-notifier update-notifier-common || log::info "Update notifier not present or already purged."
        log::success "Finished attempting to purge update-notifier."
    else
        log::info "Not an apt-based system, skipping update-notifier purge."
    fi
}

system::check_and_install() {
    local cmd="$1"
    log::info "Checking for $cmd..."
    if system::is_command "$cmd"; then
        log::success "$cmd is already installed."
        return 0
    fi
  
    log::warning "$cmd not found. Installing…"
    system::install_pkg "$cmd"
  
    if system::is_command "$cmd"; then
        log::success "$cmd installed successfully."
    else
        log::error "Could not install $cmd—please install it manually."
        exit "${ERROR_DEPENDENCY_MISSING}"
    fi
}