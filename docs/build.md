# Build

This guide explains how to build (compile and package) **StartupFromScratch** for development and production.

## Prerequisites

- **Node.js** (v18+)
- **Yarn** (v4) installed via Corepack
- **TypeScript** v5.4.5 (configured in `package.json`)
- **Environment files**:
  - `.env-dev` (development), or
  - `.env-prod` (production)

## Build Script (`scripts/build.sh`)

All build logic is encapsulated in `scripts/build.sh`, which accepts a **production** flag (`-p` or `--production`) to switch environments.

### Usage

```bash
# Development build (uses .env-dev)
bash scripts/build.sh

# Production build (uses .env-prod)
bash scripts/build.sh --production
```

### Script Workflow

1. **Load utilities** (`scripts/utils.sh`) and parse the production flag.  
2. **Set `ENV_FILE`** to `.env-dev` or `.env-prod` and export it.  
3. **Clean**: remove previous `dist/` folders under each package.  
4. **Build**:  
   - Run Prisma Client generation:
     ```bash
     yarn workspace @startupfromscratch/prisma-db generate --schema=packages/prisma-db/prisma/schema.prisma
     ```
   - Build the server package:
     ```bash
     yarn workspace @startupfromscratch/server build
     ```
   - Build the UI package:
     ```bash
     yarn workspace @startupfromscratch/ui build
     ```
5. **CLI Packaging** (optional): use `pkg` to bundle entrypoints into single-file executables.  
6. **Zip Artifacts**:
   - Reads project version from `package.json`.  
   - Copies each package's `dist/` folder into `/var/tmp/<version>/` with `<pkg>-dist` naming.  

Artifacts are now ready for deployment (e.g. `scripts/deploy.sh`) or manual distribution.

## Verifying the Build

After running `bash scripts/build.sh` (or `yarn build`):

```text
/var/tmp/<version>/
  server-dist/
  ui-dist/
```

--- 