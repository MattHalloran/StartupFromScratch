#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Load utilities
source "$SCRIPT_DIR/../utils/logging.sh"
source "$SCRIPT_DIR/../utils/env.sh"

# Load deployment scripts
source "$SCRIPT_DIR/../deploy/docker.sh"
source "$SCRIPT_DIR/../deploy/k8s.sh"
source "$SCRIPT_DIR/../deploy/vps.sh"

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
      log_error "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Determine env file based on target
ENV_FILE=".env-dev" # Default for staging
if [ "$target" = "prod" ]; then
  ENV_FILE=".env-prod"
fi
export ENV_FILE

log_info "Starting deployment to $target (Type: ${deploy_type:-auto-detect}) using $ENV_FILE..."

# Perform build first (assuming build artifacts are needed)
# Consider adding a flag to skip build if desired
log_info "Running build before deployment..."
"$SCRIPT_DIR/build.sh" ${target:+ -p}

log_info "Executing deployment logic..."

# Deployment logic (determine based on type or environment)
if [ "$deploy_type" = "docker" ]; then
  deploy_docker "$target"
elif [ "$deploy_type" = "k8s" ]; then
  deploy_k8s "$target"
elif [ "$deploy_type" = "vps" ]; then
  deploy_vps "$target"
else
  # Auto-detect or default logic (add based on project needs)
  log_warn "Deployment type not specified or auto-detection not implemented. Defaulting (example: VPS)."
  deploy_vps "$target"
fi

log_success "Deployment to $target completed." 