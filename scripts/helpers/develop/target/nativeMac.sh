#!/usr/bin/env bash
# Posix-compliant script to setup the project for native Mac development
set -euo pipefail

DEVELOP_TARGET_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${DEVELOP_TARGET_DIR}/../../utils/log.sh"
# shellcheck disable=SC1091
source "${DEVELOP_TARGET_DIR}/../../utils/system.sh"

brew_install() {
    if ! system::is_command "brew"; then
        echo "Homebrew not found, installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "Homebrew is already installed."
    fi
}

volta_install() {
    if ! system::is_command "volta"; then
        echo "Volta not found, installing..."
        brew install volta
    else
        echo "Volta is already installed."
    fi
}

node_pnpm_setup() {
    volta install node
    volta install pnpm
}

gnu_tools_install() {
    brew install coreutils findutils
}

docker_compose_infra() {
    docker-compose up -d
}

setup_native_mac() {
    log::header "Setting up native Mac development..."
    brew_install
    volta_install
    node_pnpm_setup
    gnu_tools_install
    docker_compose_infra
}
