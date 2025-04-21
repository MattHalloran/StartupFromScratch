#!/usr/bin/env bash
set -e

# Load utilities
source "$(dirname "$0")/utils.sh"

# Default to staging (non-production)
production=0
# Parse flags: first argument may be staging/prod or -p/--production
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    staging)
      target=staging; shift;;
    prod|production)
      target=production; shift;;
    -p|--production)
      production=1; shift;;
    *) shift;;
  esac
done

# Override target if -p passed
target=${production:-$target}

# Choose env file
if [ "$target" = "production" ]; then
  ENV_FILE=.env-prod
else
  ENV_FILE=.env-dev
fi
export ENV_FILE

echo "🚀 Deploying to $target with $ENV_FILE..."

if [[ "$target" =~ ^(staging|production)$ ]]; then
  if [ "$USE_K8S" = "true" ]; then
    echo "Applying Kubernetes manifests..."
    kubectl apply -f k8s/$target
  else
    echo "Deploying via SSH to remote $DEPLOY_HOST..."
    ssh -i "$SSH_KEY" "$DEPLOY_USER@$DEPLOY_HOST" "mkdir -p /var/www/app && exit"
    # Copy built packages (server, ui, etc.) from the temp directory to the VPS
    temp_artifact_dir="/var/tmp/$(node -p \"require('./package.json').version\")"
    echo "Copying artifacts from $temp_artifact_dir..."
    scp -r -i "$SSH_KEY" "$temp_artifact_dir/" "$DEPLOY_USER@$DEPLOY_HOST:/var/www/app/"
    echo "Restarting service..."
    ssh -i "$SSH_KEY" "$DEPLOY_USER@$DEPLOY_HOST" "systemctl restart app.service"
  fi
else
  echo "Unknown target: $target"
  exit 1
fi

echo "✅ Deployment to $target complete." 