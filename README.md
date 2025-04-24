# StartupFromScratch

A monorepo for the Vrooli deployment-from-scratch experiment.

This project demonstrates:
- A PNPM workspace setup
- Docker Compose for local development with Postgres (pgvector) and Redis
- TypeScript 5.4.5 for all packages (server, jobs, Prisma DB, Redis DB, shared, UI)
- Vite-powered React UI with MUI
- Co‑located Mocha/Chai/Sinon tests
- Lifecycle scripts (`setup`, `develop`, `build`, `deploy`)
- GitHub Actions CI/CD pipelines for `dev` (staging) and `master` (prod)
- Flexible deployment strategies
- Ability to convert build to Windows/Mac/Android/iOS apps

## Quickstart

1. Clone the repo:
   ```bash
   git clone <repo-url> StartupFromScratch
   cd StartupFromScratch
   ```
2. Run initial setup:
   ```bash
   pnpm run setup
   ```
3. Start development (Docker):
   ```bash
   pnpm run develop
   ```
   - Spins up Postgres and Redis containers and runs server, jobs, and UI locally via TypeScript dev servers.

To run without Docker (requires local SQLite):
```bash
USE_DOCKER=false pnpm run develop
```
   - Uses SQLite and launches the same TypeScript dev servers for server, jobs, and UI.

4. Run tests:
   ```bash
   pnpm test
   ```

5. Build for production:
   ```bash
   pnpm run build
   ```

6. Deploy:
   ```bash
   pnpm run deploy staging   # or 'prod'
   ``` 