# CI/CD Guide

This guide explains the Continuous Integration and Continuous Deployment (CI/CD) setup for **StartupFromScratch** using GitHub Actions.

## Overview

We have two main workflows defined in `.github/workflows/`:

1.  **`dev.yml`**: Triggered on pushes/PRs to the `dev` branch. Deploys to the **staging** environment.
2.  **`master.yml`**: Triggered on pushes to the `master` branch. Deploys to the **production** environment.

Both workflows follow these steps:
1.  **Checkout**: Get the latest code.
2.  **Setup Node.js & Yarn**: Configure Node.js v18 and install dependencies using Yarn v4.
3.  **Lint**: Run code linting checks (`yarn lint`).
4.  **Test**: Run unit tests (`yarn test`).
5.  **Build**: Build the application (`yarn build`).
6.  **Setup SSH Key**: Write the SSH private key (from secrets) to a file for deployment.
7.  **Deploy**: Run `scripts/deploy.sh` with the appropriate target (`staging` or `prod`), passing necessary secrets.

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
    *   Create a systemd service file (e.g., `/etc/systemd/system/app.service`) to run the Node.js server. The `deploy.sh` script assumes this service is named `app.service`. **Make sure the `WorkingDirectory` and `ExecStart` paths match your `VPS_DEPLOY_PATH`**.

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

*   `ignore_lint_errors` (checkbox, default: unchecked): If checked, the workflow will continue to the next step even if the `yarn lint` command fails.
*   `ignore_test_errors` (checkbox, default: unchecked): If checked, the workflow will continue to the next step even if the `yarn test` command fails.

**Note:** These options only affect manually triggered runs. Runs triggered by pushes or pull requests will always fail if linting or tests fail.

--- 