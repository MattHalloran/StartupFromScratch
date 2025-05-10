#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${BUILD_DIR}/../utils/locations.sh"
# shellcheck disable=SC1091
source "${BUILD_DIR}/../utils/log.sh"

# Zips build artifacts for deployment
zip_artifacts() {
  local target_env="$1"
  local version="$2"
  log::info "Zipping artifacts for $target_env (Version: $version)..."

  local outdir="${DEST_DIR}/${version}"
  mkdir -p "$outdir"

  # Collect built dist folders using absolute path
  for pkg in "${PACKAGES_DIR}/"*; do
    if [ -d "$pkg/dist" ]; then
      log::info "  Collecting $(basename "$pkg") distribution..."
      cp -r "$pkg/dist" "$outdir/$(basename "$pkg")-dist"
    fi
  done

  # Add other necessary files using absolute path
  log::info "  Collecting root configuration files..."
  cp "${ROOT_DIR}/package.json" "$outdir"
  cp "${ROOT_DIR}/pnpm-lock.yaml" "$outdir"
  cp "${ROOT_DIR}/pnpm-workspace.yaml" "$outdir"

  # Create a zip archive (optional)
  # zip -r "${outdir}/app-${version}-${target_env}.zip" "$outdir"

  log::success "Build artifacts have been collected in $outdir"
} 