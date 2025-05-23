#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${DEPLOY_DIR}/env.sh"
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
  local base_values_file="$chart_path/values.yaml"

  # Select appropriate values file
  local env_values_file="$chart_path/values-$target_env.yaml"
  if [[ ! -f "$env_values_file" ]]; then
    log::warning "Environment-specific Helm values file '$env_values_file' not found. Only base '$base_values_file' will be used if it exists."
    # Set env_values_file to empty if not found, so it can be conditionally omitted from helm command if desired,
    # or ensure the helm command handles a non-existent -f path gracefully (helm usually ignores non-existent -f files)
    # For simplicity, we'll let helm handle it, or rely on base_values_file only.
    # A more robust check would ensure at least one values file is valid.
    env_values_file="" # Helm typically ignores -f for a non-existent file.
  fi

  if [[ ! -f "$base_values_file" ]]; then
    log::error "Base Helm values file '$base_values_file' not found. Cannot proceed."
    exit 1
  fi

  log::info "Using Helm chart: $chart_path"
  log::info "Release name: $release_name"
  log::info "Target namespace: $namespace (will be created if it doesn't exist)"
  log::info "Using base values file: $base_values_file"
  if [[ -n "$env_values_file" && -f "$env_values_file" ]]; then
    log::info "Using environment values file: $env_values_file"
  fi

  log::info "Linting Helm chart: $chart_path"
  if ! helm lint "$chart_path"; then
    log::error "Helm chart linting failed. Please fix the chart issues before proceeding."
    exit 1
  fi

  # Determine the image tag to use based on the environment
  local tag_to_set
  if env::in_production; then
    # For production, it's highly recommended to use a specific, immutable image version
    # (e.g., a Git commit SHA or semantic version) instead of a floating 'prod' tag.
    # This variable would ideally be set by the CI/CD pipeline after a successful build and push.
    # For now, defaulting to "prod" as per the simplified approach.
    tag_to_set="prod"
    log::warning "Using '$tag_to_set' tag for production. Consider using immutable versioned tags for true production deployments."
  else
    tag_to_set="dev"
    log::info "Using '$tag_to_set' tag for $target_env environment."
  fi

  local image_tag_overrides=()
  image_tag_overrides+=("--set" "services.ui.tag=$tag_to_set")
  image_tag_overrides+=("--set" "services.server.tag=$tag_to_set")
  image_tag_overrides+=("--set" "services.jobs.tag=$tag_to_set")

  log::info "Applying image tag overrides: UI_TAG=$tag_to_set, SERVER_TAG=$tag_to_set, JOBS_TAG=$tag_to_set"

  if [[ "$target_env" == "prod" || "$target_env" == "production" ]]; then
    log::warning "----------------------------------------------------------------"
    log::warning "IMPORTANT FOR PRODUCTION DEPLOYMENT (Helm + Vault Secrets Operator):"
    log::warning "This deployment relies on the Vault Secrets Operator (VSO) if enabled in your Helm values."
    log::warning "Ensure that:"
    log::warning "  1. Your HashiCorp Vault instance is populated with the required secrets."
    log::warning "  2. The Helm values files ('$base_values_file', '${env_values_file:-not specified or found}') correctly configure VSO connection and secret paths."
    log::warning "  3. VSO is enabled (e.g., '.Values.vso.enabled: true') in your effective Helm configuration."
    log::warning "Secrets should NOT be passed directly via 'helm --set' for production if VSO is in use."
    log::warning "Refer to k8s/README.md for VSO setup details."
    log::warning "----------------------------------------------------------------"
  fi

  # Optional: Add a dry-run step here, perhaps controlled by a flag or for specific environments
  # log::info "Performing Helm dry-run..."
  # helm upgrade --install "$release_name" "$chart_path" \
  #   --namespace "$namespace" \
  #   --create-namespace \
  #   -f "$base_values_file" \
  #   ${env_values_file:+-f "$env_values_file"} \
  #   "${image_tag_overrides[@]}" \
  #   --dry-run --debug || { log::error "Helm dry-run failed."; exit 1; }
  # log::info "Dry-run successful. Proceeding with actual deployment."
  # # Add a confirmation step here if interactive, e.g. read -p "Continue with deployment? (y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

  # Execute Helm command
  log::info "Running Helm upgrade --install..."
  if helm upgrade --install "$release_name" "$chart_path" \
    --namespace "$namespace" \
    --create-namespace \
    -f "$base_values_file" \
    ${env_values_file:+-f "$env_values_file"} \
    "${image_tag_overrides[@]}" \
    --atomic \
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
