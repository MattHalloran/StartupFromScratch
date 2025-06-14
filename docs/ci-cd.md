# CI/CD Guide

This guide explains the Continuous Integration and Continuous Deployment (CI/CD) setup for **StartupFromScratch** using GitHub Actions.

## Overview

We have two main workflows defined in `.github/workflows/`:

1.  **`dev.yml`**: Triggered on pushes/PRs to the `dev` branch. Deploys to the **staging** environment.
2.  **`master.yml`**: Triggered on pushes to the `master` branch. Deploys to the **production** environment.

Both workflows follow these steps:
1.  **Checkout**: Get the latest code.
2.  **Setup Node.js & pnpm**: Configure Node.js v18 and install dependencies using pnpm.
3.  **Lint**: Run code linting checks (`pnpm run lint`). Skipped if `run_lint=false`. Failures do not block the workflow.
4.  **Test**: Run unit tests (`pnpm test`). Skipped if `run_test=false`. Failures do not block the workflow.
5.  **Build**: Build the application (`pnpm run build`).
6.  **Configure SSH**: Disable strict host-key checking on the Actions runner.
7.  **Setup SSH Key**: Write the SSH private key (from environment secrets) to `~/.ssh/deploy_key` and set secure permissions.
8.  **Verify SSH connection**: Test connectivity to the VPS with `ssh -i ~/.ssh/deploy_key -o BatchMode=yes ${{ secrets.VPS_DEPLOY_USER }}@${{ secrets.VPS_DEPLOY_HOST }} "echo 'SSH OK'"`.
9.  **Deploy**: Run `scripts/main/deploy.sh --source vps --target <environment>` (e.g., `staging` or `prod`), passing `SSH_KEY_PATH`, `VPS_DEPLOY_USER`, `VPS_DEPLOY_HOST`, and `VPS_DEPLOY_PATH` as environment variables.

## GitHub Setup

### Secrets

You need to configure the following secrets in your GitHub repository settings:

**1. Repository Secrets:**
   (Settings -> Secrets and variables -> Actions -> Repository secrets)

   *   `VPS_SSH_PRIVATE_KEY`: The **private** SSH key (content, not path) that will be used to connect to your staging and production VPS instances. **Important:** Do *not* add a passphrase to this key.

**Environment Secrets:**
   (Settings -> Environments -> New environment)

   Create two environments: `staging` and `production`. For **each** environment, add the following secrets:
   (Click environment name -> Environment secrets -> Add secret)

   *   `VPS_SSH_PRIVATE_KEY`: The **private** SSH key (content, not path) that will be used to connect to the VPS for this specific environment (staging or production). **Important:** Do *not* add a passphrase to this key. You can use the same key for both environments or generate separate keys for enhanced security.
   *   `VPS_DEPLOY_USER`: The username to use when SSHing into the VPS (e.g., `ubuntu`, `deployer`).
   *   `VPS_DEPLOY_HOST`: The hostname or IP address of the VPS.
   *   `VPS_DEPLOY_PATH`: The absolute path on the VPS where the application code should be deployed (e.g., `/var/www/staging-app`, `/var/www/production-app`).

### Generating SSH Keys (if needed)

If you don't have an SSH key pair, or if you want separate keys for staging and production:

```bash
# Example for staging key:
ssh-keygen -t ed25519 -C "github-actions-deploy-staging@your-repo" -f ~/.ssh/github_deploy_key_staging
# Press Enter for no passphrase when prompted

# Example for production key:
ssh-keygen -t ed25519 -C "github-actions-deploy-prod@your-repo" -f ~/.ssh/github_deploy_key_prod
# Press Enter for no passphrase when prompted
```

*   **Private Keys (`~/.ssh/github_deploy_key_staging`, `~/.ssh/github_deploy_key_prod`)**: Copy the **entire content** of the relevant private key file (including `-----BEGIN...` and `-----END...`) and paste it into the `VPS_SSH_PRIVATE_KEY` **environment secret** for the corresponding environment (`staging` or `production`) in GitHub.
*   **Public Keys (`~/.ssh/github_deploy_key_staging.pub`, `~/.ssh/github_deploy_key_prod.pub`)**: You'll need to add the content of the relevant public key file to the `~/.ssh/authorized_keys` file on the corresponding VPS (staging or production) for the deploy user.

## Target VPS Setup (Staging & Production)

For **each** VPS instance (staging and production), you need to perform the following setup:

1.  **Add Deploy User (if needed):** Ensure the user specified in the `VPS_DEPLOY_USER` secret exists on the VPS.
2.  **Authorize Public Key:**
    *   Copy the content of the **public** SSH key (`github_deploy_key.pub`) you generated.
    *   Log in to your VPS as the deploy user.
    *   Append the public key content to the `~/.ssh/authorized_keys` file:
        ```bash
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        echo "PASTE_PUBLIC_KEY_CONTENT_HERE" >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        ```
3.  **Create Deploy Directory:** Create the directory specified in the `VPS_DEPLOY_PATH` secret and ensure the deploy user has write permissions:
    ```bash
    # Example for /var/www/staging-app owned by 'deployer'
    sudo mkdir -p /var/www/staging-app
    sudo chown deployer:deployer /var/www/staging-app
    ```
4.  **Install Node.js & Systemd Service:**
    *   Install Node.js v18+ on the VPS.
    *   Create a systemd service file (e.g., `/etc/systemd/system/app.service`) to run the Node.js server. The `deploy.sh` script (specifically `scripts/deploy/vps.sh`) assumes this service is named `app.service`. **Make sure the `WorkingDirectory` and `ExecStart` paths match your `VPS_DEPLOY_PATH`**.

    *Example `app.service` (adjust paths and user as needed):*
    ```ini
    [Unit]
    Description=StartupFromScratch App Server
    After=network.target

    [Service]
    User=deployer # Match VPS_DEPLOY_USER
    Group=deployer # Match VPS_DEPLOY_USER's group
    WorkingDirectory=/var/www/staging-app # Match VPS_DEPLOY_PATH
    # Load environment variables from .env file deployed with the app
    EnvironmentFile=/var/www/staging-app/.env-prod # Or .env-dev for staging
    # Run the compiled server entrypoint
    ExecStart=/usr/bin/node /var/www/staging-app/server-dist/index.js
    Restart=always
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
    ```
    *   Enable and start the service:
        ```bash
        sudo systemctl enable app.service
        sudo systemctl start app.service
        ```

## Triggering Deployments

*   **Staging:** Push changes to the `dev` branch or create a Pull Request targeting `dev`.
*   **Production:** Push changes to the `master` branch.

You can also manually trigger the workflows from the GitHub Actions tab using the "Run workflow" button. When triggering manually, you have the following options:

*   `run_lint` (checkbox, default: checked): If unchecked, the lint step will be skipped.
*   `run_test` (checkbox, default: checked): If unchecked, the test step will be skipped.

**Note:** Both lint and test steps run by default and their failures do not block deployment. You can use the above options to skip them in manual runs.

---
### Kubernetes Deployments

Our CI/CD workflows can also deploy to Kubernetes clusters using the `scripts/main/deploy.sh` helper with `--source k8s`.

#### Configuring `kubectl` Access in GitHub Actions

Before running the deployment step, you must configure `kubectl` so it can communicate with your Kubernetes cluster. You can do this in two ways:

1. **Using a base64-encoded kubeconfig file**
   - Store your cluster's kubeconfig file as a GitHub Actions secret named `KUBECONFIG_CONTENT_BASE64` (its content base64-encoded).
   - In your workflow, decode it and write to `~/.kube/config`:
     ```yaml
     - name: Configure kubectl (KUBECONFIG_CONTENT_BASE64)
       run: |
         mkdir -p ~/.kube
         echo "${{ secrets.KUBECONFIG_CONTENT_BASE64 }}" | base64 -d > ~/.kube/config
         export KUBECONFIG=~/.kube/config
     ```

2. **Using individual environment variables**
   - Set the following secrets in GitHub Actions:
     - `KUBE_API_SERVER`: API server URL of your Kubernetes cluster.
     - `KUBE_CA_CERT_PATH`: Base64-encoded CA certificate (or path to a CA file on the runner).
     - `KUBE_BEARER_TOKEN` _or_ `KUBE_CLIENT_CERT_PATH` & `KUBE_CLIENT_KEY_PATH`: Credentials for authentication.
   - Example snippet:
     ```yaml
     - name: Export Kubernetes variables
       run: |
         echo "KUBE_API_SERVER=${{ secrets.KUBE_API_SERVER }}" >> $GITHUB_ENV
         echo "KUBE_CA_CERT_PATH=${{ secrets.KUBE_CA_CERT_PATH }}" >> $GITHUB_ENV
         echo "KUBE_BEARER_TOKEN=${{ secrets.KUBE_BEARER_TOKEN }}" >> $GITHUB_ENV
     ```

#### Example Workflow for Kubernetes Deployment

```yaml
jobs:
  deploy-k8s:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      # Configure kubectl access (choose one method above)
      - name: Configure kubectl
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG_CONTENT_BASE64 }}" | base64 -d > ~/.kube/config
          export KUBECONFIG=~/.kube/config

      - name: Build artifacts
        run: |
          export VERSION=$(node -p "require('./package.json').version")
          bash scripts/main/build.sh --production --version "$VERSION"

      - name: Deploy to Kubernetes
        run: |
          # Ensure VERSION and ENVIRONMENT are set, for example:
          export VERSION=$(node -p "require('./package.json').version")
          export ENVIRONMENT=production
          bash scripts/main/deploy.sh --source k8s --environment "$ENVIRONMENT" --version "$VERSION"
```

See [Kubernetes README (`k8s/README.md`)](./k8s/README.md) for details on chart configuration and values file management.

--- 