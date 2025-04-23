#!/bin/bash
# Posix-compliant script to setup the project for native Windows development/production
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../../utils/index.sh"

setup_native_win() {
    header "Setting up native Windows development/production..."

    # Check if running on Windows
    if [[ "$(uname)" != *"NT"* ]]; then
        error "This script must be run on Windows"
        exit 1
    }

    # Check if nvm-windows is installed
    if ! command -v nvm &> /dev/null; then
        info "Installing nvm-windows..."
        # Download and install nvm-windows
        powershell -Command "
            $nvmUrl = 'https://github.com/coreybutler/nvm-windows/releases/latest/download/nvm-setup.exe'
            $nvmInstaller = '$env:TEMP\nvm-setup.exe'
            Invoke-WebRequest -Uri $nvmUrl -OutFile $nvmInstaller
            Start-Process -FilePath $nvmInstaller -Wait
        "
    }

    # Install Node.js LTS version
    info "Installing Node.js LTS version..."
    nvm install lts
    nvm use lts

    # Install essential global packages
    info "Installing essential global packages..."
    pnpm add -g typescript@latest
    pnpm add -g @types/node
    pnpm add -g ts-node
    pnpm add -g eslint
    pnpm add -g prettier

    # Install project dependencies
    info "Installing project dependencies..."
    pnpm install

    # Setup environment variables
    info "Setting up environment variables..."
    if [ ! -f .env ]; then
        cp .env.example .env
    fi

    # Setup Git hooks
    info "Setting up Git hooks..."
    npm run prepare

    success "Native Windows setup completed successfully!"
}
