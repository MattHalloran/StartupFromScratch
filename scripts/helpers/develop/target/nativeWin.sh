#!/usr/bin/env bash
# Posix-compliant script for native Windows development
set -euo pipefail

DEVELOP_TARGET_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${DEVELOP_TARGET_DIR}/../../utils/logging.sh"

start_development_native_win() {
    header "Starting native Windows development environment..."

    # Check if running on Windows
    if [[ "$(uname)" != *"NT"* ]]; then
        error "This script must be run on Windows"
        exit 1
    fi

    # Ensure correct Node.js version is active
    info "Verifying Node.js version..."
    nvm use lts

    # Check and install dependencies if needed
    if [ ! -d "node_modules" ]; then
        info "Installing dependencies..."
        pnpm install
    fi

    cleanup() {
        info "Cleaning up development environment..."
        kill $TYPE_CHECK_PID $LINT_PID
        exit 0
    }
    if ! is_yes "$DETACHED"; then
        trap cleanup SIGINT SIGTERM
    fi

    # Run TypeScript type checking in watch mode in background
    info "Starting TypeScript type checking in watch mode..."
    pnpm run type-check:watch &
    TYPE_CHECK_PID=$!

    # Start ESLint in watch mode in background
    info "Starting ESLint in watch mode..."
    pnpm run lint:watch &
    LINT_PID=$!

    # Start development server
    info "Starting development server..."
    pnpm run dev

    success "Development environment started successfully!"
}
