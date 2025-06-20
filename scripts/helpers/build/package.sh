#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${BUILD_DIR}/../utils/log.sh"
# shellcheck disable=SC1091
source "${BUILD_DIR}/../utils/var.sh"

# Removes previous build artifacts by deleting all package dist directories.
package::clean_build() {
    log::header "Cleaning previous build artifacts..."
  
    # Find and delete all dist directories directly under each package directory
    # -maxdepth 2 ensures we only look in packages/* and not deeper
    find "${var_PACKAGES_DIR}" -maxdepth 2 -type d -name "dist" -prune -exec rm -rf {} +
  
    log::success "Cleaned previous build artifacts."
}

# Builds individual packages
package::build_packages() {
  log::header "Building individual packages..."

  # Build server package
  log::info "Building server package..."
  pnpm --filter @vrooli/server run build

  # Build UI package
  log::info "Building UI package..."
  pnpm --filter @vrooli/ui run build

  # Build shared packages
  log::info "Building shared packages..."
  pnpm --filter @vrooli/shared run build

  # Build jobs package
  log::info "Building jobs package..."
  pnpm --filter @vrooli/jobs run build
}

# Ensures each package with a package.json has a dist directory; exits with an error if any are missing.
package::verify_build() {
    log::header "Verifying build output..."
    local missing=0 pkg pkg_name dist_dir
  
    log::info "Checking for dist directories in packages..."
    # Iterate over items directly under packages/
    for pkg in "${var_PACKAGES_DIR}"/*; do
        # Check if it's a directory and contains a package.json (indicating it's a package)
        if [ -d "$pkg" ] && [ -f "${pkg}/package.json" ]; then
            pkg_name="$(basename "${pkg}")"
            dist_dir="${pkg}/dist"
            # Check if the dist directory *doesn't* exist
            if [ ! -d "$dist_dir" ]; then
                log::error "Build verification failed: Missing dist directory for package '${pkg_name}'"
                missing=1
            else
                log::info "Found dist directory for package '${pkg_name}'."
            fi
        fi
    done
  
    # Check the final status
    if [ "$missing" -ne 0 ]; then
        log::error "Build verification failed due to missing dist directories."
        exit "$ERROR_BUILD_FAILED" # Use the standard exit code for build failures
    else
        log::success "Build verification succeeded. All packages have dist directories."
    fi
}

# Packages CLI executables (placeholder)
package::package_cli() {
  log::header "Packaging CLI executables (placeholder)..."
  # Example: bundle a CLI entry (implement as needed)
  # pkg tools/cli.ts --targets node18-win-x64,node18-macos --out-dir dist/cli
} 