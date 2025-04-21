# Starting Prompt

This document captures the initial, approved architecture and setup plan for **StartupFromScratch**.

---

## ✅ Definitions of Success

### Emoji Legend
- ✅ = Implemented and verified through testing
- 🚧 = Implemented but needs testing/verification
- ❌ = Not yet implemented

### Project Structure & Tooling
- ✅ The project is a monorepo with packages for the server, redis-db, prisma-db, jobs, shared, and ui
- ✅ The project is git-initialized and named "StartupFromScratch"
- ✅ Use a modern package manager (Yarn v4)
- ✅ Code is written in TypeScript v5.4.5

### Infrastructure & Deployment
- 🚧 Databases use `ankane/pgvector:v0.4.4` and `redis:7.4.0-alpine` (configuration exists but needs testing)
- 🚧 Other packages use `node:18-alpine3.20` (configuration exists but needs testing)
- 🚧 Supports Docker, VPS, or Kubernetes deployments with horizontal scaling (scripts exist but need testing)
- 🚧 CI/CD workflows exist in `.github/workflows` for `dev` and `master` (workflows exist but need verification)
- 🚧 Builds use `scripts/build.sh`, including zipping to `/var/tmp/<version>/` (script exists but needs testing)
- 🚧 Deployments use `scripts/deploy.sh` (script exists but needs testing)

### Development & Testing
- ✅ Setup uses `scripts/setup.sh` (verified working)
- ✅ Development startup uses `scripts/develop.sh` (verified working)
- 🚧 Test files co‑locate with code (`*.test.ts`, `*.test.tsx`, `*.stories.tsx`) (structure exists but needs population)
- ✅ Unit tests use Mocha, Chai (v5+), and Sinon, with global setup (verified working)

### Documentation & UI
- 🚧 Documentation is comprehensive in the `/docs` folder (exists but needs review)
- 🚧 UI uses React ^18.2.0, `@mui/material@^5.15.1`, and `@mui/styles@^5.15.1` (needs verification)
- 🚧 UI is client-side rendered and supports meta tags for SSO (shown to work but not we're using dummy data)

### Platform & Configuration
- 🚧 Local runs on Windows/Mac without Docker (configuration exists but needs testing)
- ✅ All secrets in `.env-dev`/`.env-prod`, with `.env-example` (verified working)

**Important Notes:**
- Code is clean, organized, and runnable on Windows (native or WSL).
- Architecture is thoughtful and well-planned.
- Setup is simple, downloadable as a Windows/Mac app.
- Easy configuration for local or remote resources.
- Code and docs follow best practices and are maintainable.

---

## 🚀 1. Monorepo & Tooling

- **Package Manager**  
  Use **Yarn v4 (Berry)** workspaces.

- **Top‑level layout**  
  ```text
  /StartupFromScratch
  ├─ package.json         # workspace config & scripts
  ├─ yarn.lock
  ├─ tsconfig.json        # shared TS 5.4.5 settings
  ├─ .env-example
  ├─ .gitignore           # sensible defaults
  ├─ .dockerignore        # ignore node_modules, dist, .env*, etc.
  ├─ .eslintrc.js         # global linting rules
  ├─ docker-compose.yml   # local dev orchestration
  ├─ scripts/             # setup, develop, build, deploy, etc.
  └─ packages/
     ├─ server/
     ├─ prisma-db/
     ├─ redis-db/
     ├─ jobs/
     ├─ shared/
     └─ ui/
  ```

---

## 🐳 2. Docker & Local Databases

- **Services** (in `docker-compose.yml`):  
  - `postgres` → `ankane/pgvector:v0.4.4`  
  - `redis`    → `redis:7.4.0-alpine`  
  - `server`, `jobs`, `ui` → `node:18-alpine3.20`

- **Local‑only mode (no Docker)**:  
  - `prisma-db` contains two schemas:  
    - `schema.postgres.prisma` (for Docker)  
    - `schema.sqlite.prisma`   (for local runs)  
  - At startup, `scripts/develop.sh` picks by `USE_DOCKER=true|false` and symlinks to `schema.prisma`.

- **.env files**:  
  - Root `.env-dev` & `.env-prod` mounted into containers.  
  - `.env-example` lists all required keys.

---

## 🔧 3. ESLint, TypeScript & Testing

- **ESLint**:  
  Root `.eslintrc.js` extending `eslint:recommended` and `plugin:@typescript-eslint/recommended`.

- **TypeScript** v5.4.5:  
  Root `tsconfig.json`; each package extends it.

- **Tests**:  
  - Co‑locate alongside code (`*.test.ts`, `*.test.tsx`, `*.stories.tsx`).  
  - Global setup in `packages/**/__test__/setup.js` (imported by Mocha via `--file`).  
  - Dev dependencies: `mocha`, `chai@^5.0.0`, `sinon`.

---

## 🖥️ 4. Windows/Mac "One‑Click" Start

- Use [pkg](https://github.com/vercel/pkg) or `nexe` to bundle a small CLI entrypoint into:
  - `StartupFromScratch-win.exe`  
  - `StartupFromScratch-mac`

These binaries:
1. Read `.env-…`  
2. Spin up Node server (SQLite if `USE_DOCKER=false`)  
3. Launch default browser at `http://localhost:…`

---

## 💻 5. Lifecycle Scripts

Defined in `package.json` and `scripts/`:

- **setup.sh**:  
  - Yarn install, generate Prisma client, copy `.env-example` → `.env-dev`.

- **develop.sh**:  
  - If `USE_DOCKER=true`: `docker-compose up --build`.  
  - Else: run TS watchers (`server`, `jobs`, `ui`) + local SQLite migrations.

- **build.sh**:  
  - Transpile all packages to `dist/`.  
  - Package CLI binaries via pkg.  
  - Zip everything to `/var/tmp/<version>/`.

- **deploy.sh**:  
  - Accepts target (`staging|prod`).  
  - Docker: push images or apply K8s.  
  - VPS: SSH + `scp` zip + unpack + restart.

---

## 🔄 6. CI/CD Workflows

In `.github/workflows/`:

1. **dev.yml** (branch: `dev` & PRs):  
   - Lint → Test → Build → **Deploy to Staging** (`scripts/deploy.sh staging`).
2. **master.yml** (branch: `master`):  
   - Lint → Test → Build → **Deploy to Production** (`scripts/deploy.sh prod`).

Each uses GitHub Actions environments, concurrency, and secrets (see [GitHub Actions Deployment Guide](https://docs.github.com/en/actions/use-cases-and-examples/deploying/deploying-with-github-actions)).

---

## 📚 7. Documentation (in `/docs`)

- `architecture.md`  – system diagrams & rationale  
- `setup.md`         – install & env steps  
- `dev.md`           – local vs. Docker guide  
- `testing.md`       – writing & running tests  
- `deployment.md`    – Docker, VPS, K8s guides  
- `ci-cd.md`         – explain workflows  
- `scratch/active-plan.md` – this plan

---

*End of starting prompt.*