#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${DEPLOY_DIR}/../utils/log.sh"
# shellcheck disable=SC1091
source "${DEPLOY_DIR}/../utils/var.sh"

# Deploy application to Kubernetes using Helm
deploy::deploy_k8s() {
  local target_env="${1:-}"
  if [[ -z "$target_env" ]]; then
    log::error "Kubernetes Helm deployment: target environment (e.g., dev, staging, prod) not specified as the first argument."
    exit 1
  fi
  log::header "🚀 Starting Kubernetes Helm deployment: env=$target_env"

  # Check for Helm
  if ! command -v helm >/dev/null 2>&1; then
    log::error "Helm CLI not found; please install Helm."
    exit 1
  fi

  local chart_path="$var_ROOT_DIR/k8s/chart"
  local release_name="vrooli-$target_env"
  local namespace="$target_env" # Use target environment as namespace

  # Select appropriate values file
  local values_file="$chart_path/values-$target_env.yaml"
  if [[ ! -f "$values_file" ]]; then
    # Fallback to default values.yaml if specific environment file doesn't exist (e.g. for 'dev' if values-dev.yaml is not present)
    # However, values-dev.yaml and values-prod.yaml *do* exist. This is more of a safeguard.
    log::warning "Values file '$values_file' not found. Attempting to use default '$chart_path/values.yaml'."
    values_file="$chart_path/values.yaml"
    if [[ ! -f "$values_file" ]]; then
        log::error "Default Helm values file '$values_file' also not found."
        exit 1
    fi
  fi

  log::info "Using Helm chart: $chart_path"
  log::info "Release name: $release_name"
  log::info "Target namespace: $namespace (will be created if it doesn't exist)"
  log::info "Using values file: $values_file"

  if [[ "$target_env" == "prod" || "$target_env" == "production" ]]; then
    log::warning "----------------------------------------------------------------"
    log::warning "IMPORTANT FOR PRODUCTION DEPLOYMENT:"
    log::warning "The Helm chart will use values from '$values_file'."
    log::warning "Ensure that placeholder secrets (e.g., DB_PASSWORD) in this file"
    log::warning "are overridden with actual production secret values during CI/CD execution."
    log::warning "Example: helm upgrade ... --set secrets.DB_PASSWORD='REAL_SECRET_VALUE'"
    log::warning "----------------------------------------------------------------"
  fi

  # Execute Helm command
  log::info "Running Helm upgrade --install..."
  if helm upgrade --install "$release_name" "$chart_path" \\
    --namespace "$namespace" \\
    --create-namespace \\
    -f "$values_file" \\
    --atomic \\
    --timeout 10m; then # Wait for resources to be ready, adjust timeout as needed
    log::success "✅ Kubernetes Helm deployment completed successfully for environment: $target_env"
  else
    log::error "❌ Kubernetes Helm deployment failed for environment: $target_env"
    # Attempt to get Helm status or logs for the failed release
    log::info "Attempting to get status for release '$release_name' in namespace '$namespace'..."
    helm status "$release_name" --namespace "$namespace" || true
    log::info "Attempting to get history for release '$release_name' in namespace '$namespace'..."
    helm history "$release_name" --namespace "$namespace" || true
    exit 1
  fi
}

# If this script is run directly, invoke its main function.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    deploy::deploy_k8s "$@"
fi
