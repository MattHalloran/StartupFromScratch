# CI/CD

We use **GitHub Actions** to automate linting, testing, building, and deployment for two main branches:

| Workflow     | Trigger                                   | Environment | Deploy Target        |
|--------------|-------------------------------------------|-------------|----------------------|
| **Dev CI/CD**    | `push` / `pull_request` on `dev`, manual  | staging     | Staging server       |
| **Master CI/CD** | `push` on `master`, manual               | production  | Production server    |

## Workflow Details

### Concurrency & Environments

- Both workflows use a `concurrency` group (`dev` or `master`) to cancel in-progress runs when new commits arrive.
- Each job specifies an `environment` (staging or production) to enforce branch protections and secrets scoping.

### Job Steps

1. **Checkout** code (`actions/checkout@v3`).
2. **Setup Node.js 18** & enable Yarn cache (`actions/setup-node@v3`).
3. **Install dependencies**: `yarn install` (immutable lockfile).  
4. **Lint**: `yarn lint`.  
5. **Test**: `yarn test` (runs SWC build-tests + Mocha).  
6. **Build**: `yarn build` (TypeScript compile + package CLI).  
7. **Deploy**:
   - **Dev CI/CD**: `bash scripts/deploy.sh staging`  
   - **Master CI/CD**: `bash scripts/deploy.sh prod`

### Caching

To speed up builds, we cache:

```yaml
- name: Cache dependencies
  uses: actions/cache@v3
  with:
    path: |
      ~/.yarn/cache
      node_modules
    key: ${{ runner.os }}-yarn-${{ hashFiles('**/yarn.lock') }}
    restore-keys: |
      ${{ runner.os }}-yarn-
```

### Required Secrets

- `SSH_PRIVATE_KEY` – private key to SSH into the target server.
- `DEPLOY_USER`      – SSH user name.
- `DEPLOY_HOST`      – target host/IP for deploy.
- (Optional) `USE_K8S` – if set to `true`, uses Kubernetes manifests instead of SSH.

Place secrets in **Settings → Secrets & variables → Actions**.

### Manual Triggers

Both workflows support `workflow_dispatch` for ad-hoc runs from the Actions UI.

--- 