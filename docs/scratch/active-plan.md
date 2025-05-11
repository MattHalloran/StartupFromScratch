# Active Plan: Harden Existing GitHub Actions CI/CD (Approach 1)

## Objective
Ensure our existing GitHub Actions workflows (`dev.yml` and `master.yml`) reliably build, test, and deploy our app to staging and production VPS instances via SSH.

## Prerequisites

1. GitHub Environments & Secrets
   - **Environments**: `staging`, `production`
   - For each environment, set the following **Environment secrets** (Settings → Environments → staging/production → Environment secrets):
     - `VPS_SSH_PRIVATE_KEY`: Private SSH key (no passphrase)
     - `VPS_DEPLOY_USER`: SSH user on the VPS
     - `VPS_DEPLOY_HOST`: VPS host/IP
     - `VPS_DEPLOY_PATH`: Deployment path on VPS

2. VPS Setup
   - Public key from each private key must be in `~/.ssh/authorized_keys` of `VPS_DEPLOY_USER`.
   - Deployment directory (`VPS_DEPLOY_PATH`) must exist and be owned by `VPS_DEPLOY_USER`.

## Step-by-Step Plan

### 1. Standardize Secret Names & Permissions
- Confirm the Actions workflows reference the same secret names (`VPS_SSH_PRIVATE_KEY`, `VPS_DEPLOY_USER`, `VPS_DEPLOY_HOST`, `VPS_DEPLOY_PATH`).
- Ensure workflows use **Environment secrets** for staging and production, not repository-level secrets, to isolate credentials per environment.

### 2. Harden SSH Key Handling
- In both workflows, add a step to configure SSH to disable host-key checking:

```yaml
- name: Configure SSH
  run: |
    mkdir -p ~/.ssh
    echo -e "Host *\n \tStrictHostKeyChecking no\n" > ~/.ssh/config
    chmod 600 ~/.ssh/config
```

- Write the private key and set permissions:

```yaml
- name: Set up SSH private key
  run: |
    echo "${{ secrets.VPS_SSH_PRIVATE_KEY }}" > ~/.ssh/deploy_key
    chmod 600 ~/.ssh/deploy_key
```

### 3. Verify SSH Connectivity
- Immediately after SSH setup, add a test step:

```yaml
- name: Verify SSH connection
  run: |
    ssh -i ~/.ssh/deploy_key -o BatchMode=yes ${{ secrets.VPS_DEPLOY_USER }}@${{ secrets.VPS_DEPLOY_HOST }} "echo 'SSH OK'"
```

### 4. Explicit Deploy Command Flags
- Update the deploy step to pass the flags expected by `deploy.sh`:

In `.github/workflows/dev.yml`:

```diff
- name: Deploy to Staging
- run: pnpm run deploy staging
+ name: Deploy to Staging
+ run: pnpm run deploy -- --source vps --target staging
  env:
    SSH_KEY_PATH: ~/.ssh/deploy_key
    VPS_DEPLOY_USER: ${{ secrets.VPS_DEPLOY_USER }}
    VPS_DEPLOY_HOST: ${{ secrets.VPS_DEPLOY_HOST }}
    VPS_DEPLOY_PATH: ${{ secrets.VPS_DEPLOY_PATH }}
```

In `.github/workflows/master.yml`:

```diff
- name: Deploy to Production
- run: pnpm run deploy prod
+ name: Deploy to Production
+ run: pnpm run deploy -- --source vps --target prod
```

### 5. Enforce Failure Conditions
- Remove or set `continue-on-error: false` on Lint and Test steps for push-triggered runs, ensuring failures block merges on `dev`/`master`.

### 6. Run & Validate
1. Push these workflow changes to a test branch targeting `dev`.
2. Confirm the Actions run successfully, the SSH connectivity check passes, and the staging server receives the deploy.
3. Iterate on any failure logs.

### 7. Sync Documentation
- Update `docs/ci-cd.md` to reflect:
  - The new "Configure SSH" and "Verify SSH connection" steps.
  - The updated deploy commands using "--source"/"--target" flags.
  - Any changes to secret names or environment configuration.

## Deliverables
- Updated `.github/workflows/dev.yml` and `master.yml`.
- Verified SSH connectivity step.
- Updated `docs/ci-cd.md` with the new workflow structure.
- Proof of successful staging deployment in GitHub Actions logs.

## Timeline
- **Day 1:** Configure secrets & update workflows.
- **Day 2:** Test on staging and troubleshoot.
- **Day 3:** Merge to `dev`, monitor; then merge to `master` and validate production. 