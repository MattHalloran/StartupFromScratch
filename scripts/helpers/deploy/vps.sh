#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# shellcheck disable=SC1091
source "${DEPLOY_DIR}/../utils/log.sh"

# Placeholder for VPS deployment logic
deploy_vps() {
  local target_env="$1"
  local artifact_dir="${2:-}"
  log::info "Deploying ZIP bundle to VPS environment: $target_env from $artifact_dir"
  # Copy all built files to the VPS deployment path
  scp -i "$SSH_KEY_PATH" -r "$artifact_dir"/. "${VPS_DEPLOY_USER}@${VPS_DEPLOY_HOST}:${VPS_DEPLOY_PATH}"
  # Restart the application service on the VPS
  ssh -i "$SSH_KEY_PATH" "${VPS_DEPLOY_USER}@${VPS_DEPLOY_HOST}" <<EOF
    cd ${VPS_DEPLOY_PATH}
    sudo systemctl restart app.service
EOF
  log::success "✅ VPS deployment complete for $target_env"
}
