#!/usr/bin/env bash

# Zips build artifacts for deployment
zip_artifacts() {
  local target_env="$1"
  log_info "Zipping artifacts for $target_env..."

  local version=$(node -p "require('../../package.json').version")
  local outdir="/var/tmp/${version}"
  mkdir -p "$outdir"

  # Collect built dist folders
  for pkg in ../../packages/*; do
    if [ -d "$pkg/dist" ]; then
      cp -r "$pkg/dist" "$outdir/$(basename $pkg)-dist"
    fi
  done

  # Add other necessary files (e.g., package.json, pnpm-lock.yaml, pnpm-workspace.yaml) for deployment
  cp ../../package.json "$outdir"
  cp ../../pnpm-lock.yaml "$outdir"
  cp ../../pnpm-workspace.yaml "$outdir"

  # Create a zip archive (optional)
  # zip -r "${outdir}/app-${version}-${target_env}.zip" "$outdir"

  log_success "Build artifacts have been collected in $outdir"
} 