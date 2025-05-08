#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${DEPLOY_DIR}/../utils/locations.sh"
# shellcheck disable=SC1091
source "${DEPLOY_DIR}/../utils/logging.sh"

# Placeholder for Docker deployment logic
deploy_docker() {
  local target_env="$1"
  local artifact_dir="${2:-}"

  # Extract build artifacts if archive is present
  if [[ -n "$artifact_dir" && -f "$artifact_dir/build.tar.gz" ]]; then
    info "Extracting build artifacts from $artifact_dir/build.tar.gz"
    pushd "$PACKAGES_DIR" >/dev/null || { error "Failed to change to packages directory"; return 1; }
    tar -xzf "$artifact_dir/build.tar.gz"
    popd >/dev/null
    success "Build artifacts extracted"
  fi

  # Load Docker images if archive is present
  if [[ -n "$artifact_dir" && -f "$artifact_dir/docker-images.tar.gz" ]]; then
    info "Loading Docker images from $artifact_dir/docker-images.tar.gz"
    docker load -i "$artifact_dir/docker-images.tar.gz"
    if [[ $? -ne 0 ]]; then
      error "Failed to load Docker images from archive"
      return 1
    fi
    success "Docker images loaded from archive"
  fi

  # Select compose file based on target environment
  local compose_file
  if [[ "$target_env" == "prod" ]]; then
    compose_file="${ROOT_DIR}/docker-compose-prod.yml"
  else
    compose_file="${ROOT_DIR}/docker-compose.yml"
  fi

  info "Using Docker Compose file: $compose_file"

  # Navigate to project root
  pushd "$ROOT_DIR" >/dev/null || {
    error "Failed to change directory to project root: $ROOT_DIR"
    return 1
  }

  # Start services in detached mode and remove stale containers
  info "Starting Docker containers in detached mode"
  docker-compose -f "$compose_file" up -d --remove-orphans
  if [[ $? -ne 0 ]]; then
    error "Failed to start Docker containers using $compose_file"
    popd >/dev/null
    return 1
  fi

  # Return to original directory
  popd >/dev/null

  success "✅ Docker deployment completed for environment: $target_env"
}
