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
   - `scripts/deploy/k8s.sh::deploy_k8s`: Apply Kubernetes manifests from `k8s/<target>/`.
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

```bash
export USE_K8S=true
# Ensure kubeconfig is set for your cluster
bash scripts/main/deploy.sh staging --type k8s
```

## Kubernetes Manifests

Manifests are stored under `k8s/`:
```
k8s/
└── staging/
    ├ deployment.yaml
    └ service.yaml
└── production/
    ├ deployment.yaml
    └ service.yaml
```
Customize resource counts (replicas, CPU/memory) per environment.

--- 