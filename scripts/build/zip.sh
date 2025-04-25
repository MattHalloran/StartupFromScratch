#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"

# Zips build artifacts for deployment
zip_artifacts() {
  local target_env="$1"
  local version="$2"
  info "Zipping artifacts for $target_env (Version: $version)..."

  local outdir="/var/tmp/${version}"
  mkdir -p "$outdir"

  # Collect built dist folders using absolute path
  for pkg in "${HERE}/../../packages/"*; do
    if [ -d "$pkg/dist" ]; then
      info "  Collecting $(basename "$pkg") distribution..."
      cp -r "$pkg/dist" "$outdir/$(basename "$pkg")-dist"
    fi
  done

  # Add other necessary files using absolute path
  info "  Collecting root configuration files..."
  cp "${HERE}/../../package.json" "$outdir"
  cp "${HERE}/../../pnpm-lock.yaml" "$outdir"
  cp "${HERE}/../../pnpm-workspace.yaml" "$outdir"

  # Create a zip archive (optional)
  # zip -r "${outdir}/app-${version}-${target_env}.zip" "$outdir"

  success "Build artifacts have been collected in $outdir"
} 