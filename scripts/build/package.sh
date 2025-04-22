#!/usr/bin/env bash

# Cleans previous build artifacts
clean_build() {
  log_info "Cleaning previous build artifacts..."
  find ../../packages -maxdepth 2 -type d -name dist -exec rm -rf {} +
}

# Builds individual packages
build_packages() {
  log_info "Building individual packages..."

  # Generate Prisma client (ensure correct schema path relative to execution dir)
  log_info "Generating Prisma client..."
  pnpm --filter @vrooli/prisma run generate -- --schema=packages/prisma/prisma/schema.prisma

  # Build server package
  log_info "Building server package..."
  pnpm --filter @vrooli/server run build

  # Build UI package
  log_info "Building UI package..."
  pnpm --filter @vrooli/ui run build
}

# Packages CLI executables (placeholder)
package_cli() {
  log_info "Packaging CLI executables (placeholder)..."
  # Example: bundle a CLI entry (implement as needed)
  # pkg tools/cli.ts --targets node18-win-x64,node18-macos --out-dir dist/cli
} 