#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PACKAGES_DIR="${HERE}/../../packages"

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"

# Cleans previous build artifacts
clean_build() {
  info "Cleaning previous build artifacts..."
  find "${PACKAGES_DIR}" -maxdepth 2 -type d -name dist -exec rm -rf {} +
}

# Builds individual packages
build_packages() {
  info "Building individual packages..."

  # Build server package
  info "Building server package..."
  pnpm --filter @vrooli/server run build

  # Build UI package
  info "Building UI package..."
  pnpm --filter @vrooli/ui run build

  # Build shared packages
  info "Building shared packages..."
  pnpm --filter @vrooli/shared run build

  # Build jobs package
  info "Building jobs package..."
  pnpm --filter @vrooli/jobs run build
}

# Verifies that packages were built successfully
verify_build() {
  info "Verifying packages were built successfully..."
  local build_success=true

  # Check server package
  if [ ! -d "${PACKAGES_DIR}/server/dist" ]; then
    error "Server package build failed: dist directory not found"
    build_success=false
  fi

  # Check UI package
  if [ ! -d "${PACKAGES_DIR}/ui/dist" ]; then
    error "UI package build failed: dist directory not found"
    build_success=false
  fi

  # Check shared package
  if [ ! -d "${PACKAGES_DIR}/shared/dist" ]; then
    error "Shared package build failed: dist directory not found"
    build_success=false
  fi

  # Check jobs package
  if [ ! -d "${PACKAGES_DIR}/jobs/dist" ]; then
    error "Jobs package build failed: dist directory not found"
    build_success=false
  fi

  if [ "$build_success" = false ]; then
    error "Build verification failed"
    return 1
  else
    success "All packages built successfully"
    return 0
  fi
}

# Packages CLI executables (placeholder)
package_cli() {
  info "Packaging CLI executables (placeholder)..."
  # Example: bundle a CLI entry (implement as needed)
  # pkg tools/cli.ts --targets node18-win-x64,node18-macos --out-dir dist/cli
} 