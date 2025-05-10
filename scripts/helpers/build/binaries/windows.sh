#!/usr/bin/env bash
# scripts/build/binaries/windows.sh - Functions specific to Windows binary builds
set -euo pipefail

BUILD_BINARIES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# shellcheck disable=SC1091
source "${BUILD_BINARIES_DIR}/../../utils/flow.sh"
# shellcheck disable=SC1091
source "${BUILD_BINARIES_DIR}/../../utils/log.sh"
# shellcheck disable=SC1091
source "${BUILD_BINARIES_DIR}/../../utils/system.sh"

# Installs WineHQ Stable branch following recommended procedures
# https://wiki.winehq.org/Ubuntu
install_wine_robustly() {
    log::header "🍷 Installing WineHQ Stable for Windows builds"

    local wine_keyring="/etc/apt/keyrings/winehq-archive.key"
    local wine_sources="/etc/apt/sources.list.d/winehq-archive.sources"
    local os_release
    os_release=$(lsb_release -sc) # Get Ubuntu codename (e.g., jammy, focal)

    # Ensure dependencies are present (wget, gpg)
    system::install_pkg "wget"
    system::install_pkg "gpg"
    # system::install_pkg "apt-transport-https" # Usually included
    # system::install_pkg "ca-certificates" # Usually included

    # Need sudo for these operations
    if ! flow::can_run_sudo; then
      log::error "Sudo is required to install Wine repository and packages."
      log::info "If sudo is available but passwordless, ensure NOPASSWD is set for the user."
      log::info "Alternatively, run the build script with sudo or set SUDO_MODE=skip (if Wine is already installed)."
      # Decide action based on SUDO_MODE - skip might allow proceeding if Wine exists
      if [ "$SUDO_MODE" == "skip" ]; then
        log::warning "SUDO_MODE=skip: Skipping Wine installation check/attempt."
        log::warning "Build may fail if Wine is required and not installed."
        return 0 # Skip the rest of the function
      else
        exit "$ERROR_PERMISSIONS"
      fi
    fi

    # 1. Enable 32-bit architecture
    log::info "Enabling i386 architecture..."
    sudo dpkg --add-architecture i386

    # 2. Download and add WineHQ repository key
    log::info "Adding WineHQ repository key..."
    sudo mkdir -p /etc/apt/keyrings
    sudo rm -f "$wine_keyring" # Remove old key if exists
    sudo wget -O "$wine_keyring" https://dl.winehq.org/wine-builds/winehq.key

    # 3. Add WineHQ repository sources
    log::info "Adding WineHQ $os_release repository source..."
    # Using Jammy source even for later releases as per WineHQ recommendation sometimes
    # Check https://dl.winehq.org/wine-builds/ubuntu/dists/ for your specific release
    sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/${os_release}/winehq-${os_release}.sources
    # Example structure of the .sources file:
    # Types: deb
    # URIs: https://dl.winehq.org/wine-builds/ubuntu/
    # Suites: jammy
    # Components: main
    # Architectures: amd64 i386
    # Signed-By: /etc/apt/keyrings/winehq-archive.key

    # 4. Update package information (handles potential locks internally)
    log::info "Updating package lists after adding WineHQ repo..."
    if ! sudo apt-get update; then
      log::error "apt-get update failed after adding WineHQ repo. Check for conflicts or network issues."
      exit "$ERROR_NETWORK"
    fi

    # 5. Install WineHQ Stable
    log::info "Installing winehq-stable package..."
    # Use apt-get with a longer timeout directly, avoiding the wrapper script's potential issues
    if ! timeout 600s sudo apt-get install --install-recommends -y winehq-stable; then
       log::error "Failed to install winehq-stable package. Check apt logs."
       # Optional: Add fallback to wine64? system::install_pkg "wine64"
       exit "$ERROR_DEPENDENCY"
    fi

    log::success "WineHQ Stable installation completed."
}
