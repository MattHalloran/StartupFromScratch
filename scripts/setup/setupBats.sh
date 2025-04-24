#!/usr/bin/env bash
# Posix-compliant script to setup bats and its dependencies
set -euo pipefail

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BATS_DEPENDENCIES_DIR="${HERE}/../__tests/helpers"

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"

# Function to determine and export BATS_PREFIX based on environment and sudo mode
_determine_bats_prefix() {
    # Default Bats installation prefix unless overridden by environment variable
    local prefix=${BATS_PREFIX:-/usr/local}

    # Check if we need to switch to user-local dir
    # Condition: Default prefix is used AND (sudo mode is skip OR sudo cannot be run)
    if [ "$prefix" = "/usr/local" ] && { [ "${SUDO_MODE:-error}" = "skip" ] || ! can_run_sudo; }; then
        prefix="$HOME/.local"
        info "Sudo unavailable/skipped: switching Bats install prefix to $prefix"
        # Ensure the local bin directory exists for Bats install and PATH update
        mkdir -p "$prefix/bin" # Bats install.sh might expect the base prefix to exist
    elif [ "$prefix" != "/usr/local" ]; then
        info "Using user-defined BATS_PREFIX: $prefix"
    else
        info "Using default Bats install prefix: $prefix"
    fi
    export BATS_PREFIX="$prefix" # Export the final determined value
}

# Function to create directory to store bats core and dependencies
create_bats_dependencies_dir() {
    mkdir -p "$BATS_DEPENDENCIES_DIR"
}

# Function to clone and confirm a bats dependency
install_bats_dependency() {
    local repo_url=$1
    local dir_name=$2
    cd "$BATS_DEPENDENCIES_DIR"
    if [ ! -d "$dir_name" ]; then
        git clone "$repo_url" "$dir_name"
        success "$dir_name installed successfully at $(pwd)/$dir_name"
    else
        info "$dir_name is already installed"
    fi
    cd "$ORIGINAL_DIR"
}

# Install Bats-core
install_bats_core() {
    _determine_bats_prefix # Determine prefix just before installation

    cd "$BATS_DEPENDENCIES_DIR"
    if [ ! -d "bats-core" ]; then
        git clone https://github.com/bats-core/bats-core.git
        cd bats-core
        mkdir -p "$BATS_PREFIX"
        if can_run_sudo; then
            info "Installing Bats-core into $BATS_PREFIX (with sudo)"
            sudo ./install.sh "$BATS_PREFIX"
        else
            info "Installing Bats-core into $BATS_PREFIX (no sudo)"
            ./install.sh "$BATS_PREFIX"
        fi
        success "Bats-core installed successfully into $BATS_PREFIX"
        cd ..
    else
        info "Bats-core is already installed"
    fi
    cd "$ORIGINAL_DIR"
}

# Install Bats for testing bash scripts
install_bats() {
    _determine_bats_prefix # Determine prefix before potentially updating PATH

    header "Installing Bats and dependencies for Bash script testing"

    # Create dependencies directory
    create_bats_dependencies_dir

    # Install Bats-core
    install_bats_core

    # Install other dependencies
    install_bats_dependency "https://github.com/bats-core/bats-support.git" "bats-support"
    install_bats_dependency "https://github.com/jasonkarns/bats-mock.git" "bats-mock"
    install_bats_dependency "https://github.com/bats-core/bats-assert.git" "bats-assert"

    # Ensure Bats bin directory is in PATH without duplicates
    if [[ ":$PATH:" != *":$BATS_PREFIX/bin:"* ]]; then
        export PATH="$BATS_PREFIX/bin:$PATH"
        info "Added $BATS_PREFIX/bin to PATH"
    fi

    success "Bats and dependencies installed successfully"
}
