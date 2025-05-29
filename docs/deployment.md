# Deployment

This guide describes how to deploy **StartupFromScratch** to different environments using our `scripts/main/deploy.sh` helper or Kubernetes manifests.

## Prerequisites

- **SSH credentials** (for VPS):
  - `SSH_KEY` (private key file path)
  - `DEPLOY_USER` (remote user)
  - `DEPLOY_HOST` (remote host or IP)
- **Kubernetes CLI** (`kubectl`) if deploying to a cluster
- Environment files:
  - `.env-dev` / `.env-prod` for application configuration
- `scripts/main/deploy.sh` is executable (`chmod +x scripts/main/deploy.sh`)

## Using `scripts/main/deploy.sh`

The main deploy script sources components from `scripts/deploy/` and `scripts/utils/`. It accepts a target argument (`staging` or `production`) and an optional deployment type flag (`--type docker|k8s|vps`):

{% raw %}```bash
# Staging (default uses .env-dev, auto-detects deployment type or defaults to VPS):
bash scripts/main/deploy.sh staging

# Production (uses .env-prod, explicitly deploys via VPS):
bash scripts/main/deploy.sh production --type vps

# Production (uses .env-prod, explicitly deploys via Kubernetes):
bash scripts/main/deploy.sh production --type k8s
```{% endraw %}

The script will:
1. Load the appropriate `.env` file.
2. Run the build script (`scripts/main/build.sh`) first.
3. Determine the deployment type (based on `--type` flag or auto-detection/defaults).
4. Execute the corresponding deployment logic:
   - `scripts/deploy/k8s.sh::deploy_k8s`: Deploys to Kubernetes using a Helm chart packaged by `scripts/main/build.sh`. 
       - The `build.sh` script includes the base `k8s/chart/values.yaml` within the Helm package.
       - It also copies environment-specific values files (e.g., `k8s/chart/values-prod.yaml`) into the build artifact (`ARTIFACTS_DIR/helm-value-files/`).
       - `deploy_k8s` then uses the packaged chart along with the appropriate environment-specific values file from the artifact for the deployment (e.g., `ARTIFACTS_DIR/helm-value-files/values-prod.yaml`).
       - For production deployments, if the specific `values-prod.yaml` is not found in the artifact, the script will halt.
   - `scripts/deploy/vps.sh::deploy_vps`: Deploy via SSH (copy artifacts, restart service).
   - `scripts/deploy/docker.sh::deploy_docker`: Deploy via Docker (e.g., push images, update stack).

### Example: Deploy to VPS

```bash
export SSH_KEY=~/.ssh/id_rsa
export DEPLOY_USER=ubuntu
export DEPLOY_HOST=app.example.com
bash scripts/main/deploy.sh production --type vps
```

**Note:** Your systemd service (e.g. `app.service`) should run the SSR server entrypoint, for example:
```
[Unit]
Description=StartupFromScratch SSR Server
After=network.target

[Service]
WorkingDirectory=/var/www/app
ExecStart=/usr/bin/node /var/www/app/server-dist/index.js
Restart=always
EnvironmentFile=/var/www/app/.env-prod

[Install]
WantedBy=multi-user.target
```
The SSR server will serve:
- `/api/*` and `/webhooks/*` routes (Express handlers)
- Static UI assets from `ui-dist`
- Server‑side render all other GET requests via React

### Example: Deploy to Kubernetes

Ensure your `kubectl` is configured to point to the target Kubernetes cluster.

```bash
# Set necessary environment variables if not already set by CI/CD or your shell
# export VERSION="$(node -p "require('./package.json').version")" # Or specific version like "0.1.0"
# export ENVIRONMENT="staging" # Or "production", "dev"

# Example: Deploy the version defined by $VERSION to the $ENVIRONMENT namespace
bash scripts/main/deploy.sh --source k8s --environment "${ENVIRONMENT:-staging}" --version "${VERSION}"
# Note: Check scripts/main/deploy.sh for the most up-to-date argument parsing if needed.
# The above example assumes deploy.sh uses --source, --environment, and --version flags.
```

When deploying to Kubernetes:
- The `scripts/main/build.sh` script must have been run first with the `--version` flag (e.g., `bash scripts/main/build.sh --production --version "$VERSION"`) to produce the build artifact containing the packaged Helm chart and the versioned environment-specific Helm values files (e.g., `values-staging.yaml`, `values-prod.yaml`).
- The `scripts/helpers/deploy/k8s.sh` script (called by `deploy.sh`) will use `helm upgrade --install` with the packaged chart and the corresponding `values-<ENVIRONMENT>.yaml` file found in the build artifact.
- Image tags for production are injected into `values-prod.yaml` during the build process when you supply a `--version` flag to `build.sh`. Without `--version`, build.sh uses the version from `package.json` but does not update Helm chart files.
- For detailed information on the Helm chart structure, available configuration parameters, and how local Kubernetes development (e.g., with Minikube using `scripts/main/develop.sh`) differs, please consult the [Kubernetes README (`k8s/README.md`)](./k8s/README.md).

## Kubernetes Manifests

Manifests are stored under `k8s/chart` (we're using Helm). Please refer to [the k8s README](./k8s/README.md) for more details.
--- 