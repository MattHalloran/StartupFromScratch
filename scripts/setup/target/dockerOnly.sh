#!/bin/bash
# Posix-compliant script to setup the project for Docker only development/production
set -euo pipefail

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

source "${HERE}/../../utils/index.sh"

setup_docker_only() {
    header "Setting up Docker only development/production..."

    info "Building Docker images for all services..."
    docker-compose build

    success "✅ Docker images built successfully."
}

