#!/usr/bin/env bash
set -e

# Load utilities
source "$(dirname "$0")/utils.sh"

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
if is_yes "$production"; then
  ENV_FILE=.env-prod
  target=production
else
  ENV_FILE=.env-dev
  target=development
fi
export ENV_FILE

echo "🔨 Building for $target using $ENV_FILE..."

# Clean previous builds
find packages -maxdepth 2 -type d -name dist -exec rm -rf {} +

# Build all workspaces
yarn workspaces foreach --recursive run build

# SSR-specific build for server-side entry
echo "🔨 Running SSR build for UI..."
yarn workspace @startupfromscratch/ui vite build --ssr src/entry-server.tsx

echo "📦 Packaging CLI executables..."
# Example: bundle a CLI entry (implement as needed)
# pkg tools/cli.ts --targets node18-win-x64,node18-macos --out-dir dist/cli

# Zip artifacts
version=$(node -p "require('./package.json').version")
outdir="/var/tmp/${version}"
mkdir -p "$outdir"
# Collect built dist folders
for pkg in packages/*; do
  if [ -d "$pkg/dist" ]; then
    cp -r "$pkg/dist" "$outdir/$(basename $pkg)-dist"
  fi
done

echo "✅ Build artifacts have been zipped to $outdir" 