#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Load utilities
source "$SCRIPT_DIR/../utils/logging.sh"
source "$SCRIPT_DIR/../utils/env.sh"

# Load build scripts
source "$SCRIPT_DIR/../build/package.sh"
source "$SCRIPT_DIR/../build/zip.sh"

# Default to development
production=0
# Parse flags
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -p|--production)
      production=1; shift;;
    *) shift;;
  esac
done

# Determine env file
ENV_FILE=$(get_env_file "$production")
target=development
if is_yes "$production"; then
  target=production
fi
export ENV_FILE

log_info "Starting build for $target using $ENV_FILE..."

# Clean previous builds
clean_build

# Build packages (includes Prisma generate)
build_packages

# Package CLI executables
package_cli

# Zip artifacts
zip_artifacts "$target"

log_success "Build process completed." 