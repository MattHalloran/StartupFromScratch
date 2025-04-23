#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"
# shellcheck disable=SC1091
source "$HERE/../deploy/docker.sh"
# shellcheck disable=SC1091
source "$HERE/../deploy/k8s.sh"
# shellcheck disable=SC1091
source "$HERE/../deploy/vps.sh"

# Default target
target="staging"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    staging|prod)
      target="$1"; shift;;
    --type)
      deploy_type="$2"; shift 2;;
    *)
      error "Unknown argument: $1"
      exit "${ERROR_USAGE}"
      ;;
  esac
done

# Determine env file based on target
ENV_FILE=".env-dev" # Default for staging
if [ "$target" = "prod" ]; then
  ENV_FILE=".env-prod"
fi
export ENV_FILE

info "Starting deployment to $target (Type: ${deploy_type:-auto-detect}) using $ENV_FILE..."

# Perform build first (assuming build artifacts are needed)
# Consider adding a flag to skip build if desired
info "Running build before deployment..."
"$SCRIPT_DIR/build.sh" "${target:+ -p}"

info "Executing deployment logic..."

# Deployment logic (determine based on type or environment)
if [ "$deploy_type" = "docker" ]; then
  deploy_docker "$target"
elif [ "$deploy_type" = "k8s" ]; then
  deploy_k8s "$target"
elif [ "$deploy_type" = "vps" ]; then
  deploy_vps "$target"
else
  # Auto-detect or default logic (add based on project needs)
  warn "Deployment type not specified or auto-detection not implemented. Defaulting (example: VPS)."
  deploy_vps "$target"
fi

success "Deployment to $target completed." 