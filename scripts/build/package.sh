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

# Packages CLI executables (placeholder)
package_cli() {
  info "Packaging CLI executables (placeholder)..."
  # Example: bundle a CLI entry (implement as needed)
  # pkg tools/cli.ts --targets node18-win-x64,node18-macos --out-dir dist/cli
} 