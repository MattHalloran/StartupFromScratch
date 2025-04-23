#!/usr/bin/env bash

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname \"${BASH_SOURCE[0]}\")" && pwd)
ROOT_DIR=$(cd "$HERE"/../../.. && pwd)
source "${HERE}/../../utils/index.sh"

start_development_docker_only() {
    header "🚀 Starting Docker only development environment..."
    cd "$ROOT_DIR"

    cleanup() {
        info "🔧 Cleaning up development environment at $ROOT_DIR..."
        cd "$ROOT_DIR"
        docker-compose down
        cd "$ORIGINAL_DIR"
        exit 0
    }
    trap cleanup SIGINT SIGTERM
    info "Starting all services in detached mode (Postgres, Redis, server, jobs, UI)..."
    docker-compose up -d

    success "✅ Docker only development environment started successfully."
    info "You can view logs with 'docker-compose logs -f'."
}
