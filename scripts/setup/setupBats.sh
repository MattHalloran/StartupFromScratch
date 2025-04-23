#!/bin/bash
# Posix-compliant script to setup bats and its dependencies
set -euo pipefail

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

source "${HERE}/../utils/index.sh"

BATS_DEPENDENCIES_DIR="${HERE}/../__tests/helpers"

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
    cd "$BATS_DEPENDENCIES_DIR"
    if [ ! -d "bats-core" ]; then
        git clone https://github.com/bats-core/bats-core.git
        cd bats-core
        sudo ./install.sh /usr/local
        success "Bats-core installed successfully at $(pwd)"
        cd ..
    else
        info "Bats-core is already installed"
    fi
    cd "$ORIGINAL_DIR"
}

# Install Bats for testing bash scripts
install_bats() {
    header "Installing Bats and dependencies for Bash script testing"

    # Create dependencies directory
    create_bats_dependencies_dir

    # Install Bats-core
    install_bats_core

    # Install other dependencies
    install_bats_dependency "https://github.com/bats-core/bats-support.git" "bats-support"
    install_bats_dependency "https://github.com/jasonkarns/bats-mock.git" "bats-mock"
    install_bats_dependency "https://github.com/bats-core/bats-assert.git" "bats-assert"

    success "Bats and dependencies installed successfully"
}
