# Deployment

This guide describes how to deploy **StartupFromScratch** to different environments using our `scripts/deploy.sh` helper or Kubernetes manifests.

## Prerequisites

- **SSH credentials** (for VPS):
  - `SSH_KEY` (private key file path)
  - `DEPLOY_USER` (remote user)
  - `DEPLOY_HOST` (remote host or IP)
- **Kubernetes CLI** (`kubectl`) if deploying to a cluster
- Environment files:
  - `.env-dev` / `.env-prod` for application configuration
- `scripts/deploy.sh` is executable (`chmod +x scripts/deploy.sh`)

## Using `scripts/deploy.sh`

The deploy script accepts a target argument (`staging` or `production`) or a `-p|--production` flag:

{% raw %}```bash
# Staging (default uses .env-dev):
bash scripts/deploy.sh staging

# Production (uses .env-prod):
bash scripts/deploy.sh production
# or equivalently:
bash scripts/deploy.sh --production
```{% endraw %}

The script will:
1. Load the appropriate `.env` file (`.env-dev` or `.env-prod`).
2. If `USE_K8S=true`, apply Kubernetes manifests from `k8s/<target>/`:
   ```bash
   kubectl apply -f k8s/staging
   ```
3. Otherwise, deploy via SSH:
   - Create `/var/www/app` on the remote server.
   - Copy zip artifacts from `/var/tmp/<version>/` to the server.
   - Unzip and restart the `app.service` systemd unit.
4. Package and deploy the SSR-enabled server (in `server-dist/`), which hosts both API and SSR UI in one process.

### Example: Deploy to VPS

```bash
export SSH_KEY=~/.ssh/id_rsa
export DEPLOY_USER=ubuntu
export DEPLOY_HOST=app.example.com
bash scripts/deploy.sh production
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
bash scripts/deploy.sh staging
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