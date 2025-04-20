# StartupFromScratch

A monorepo for the Vrooli deployment-from-scratch experiment.

This project demonstrates:
- A Yarn v4 workspace setup
- Docker Compose for local development with Postgres (pgvector) and Redis
- TypeScript 5.4.5 for all packages (server, jobs, Prisma DB, Redis DB, shared, UI)
- Vite-powered React UI with MUI
- Co‑located Mocha/Chai/Sinon tests
- Lifecycle scripts (`setup`, `develop`, `build`, `deploy`)
- GitHub Actions CI/CD pipelines for `dev` (staging) and `master` (prod)

## Quickstart

1. Clone the repo:
   ```bash
   git clone <repo-url> StartupFromScratch
   cd StartupFromScratch
   ```
2. Run initial setup:
   ```bash
   yarn setup
   ```
3. Start development (Docker):
   ```bash
   yarn develop
   ```

To run without Docker (requires local SQLite):
```bash
USE_DOCKER=false yarn develop
```

4. Run tests:
   ```bash
   yarn test
   ```

5. Build for production:
   ```bash
   yarn build
   ```

6. Deploy:
   ```bash
   yarn deploy staging   # or 'prod'
   ``` 