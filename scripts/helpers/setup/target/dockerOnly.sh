#!/usr/bin/env bash
# Posix-compliant script to setup the project for Docker only development/production
set -euo pipefail

SETUP_TARGET_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${SETUP_TARGET_DIR}/../../utils/log.sh"

setup_docker_only() {
    log::header "Setting up Docker only development/production..."

    log::info "Building Docker images for all services..."
    docker-compose build

    log::success "✅ Docker images built successfully."
}

