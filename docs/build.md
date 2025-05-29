# Build

This guide explains how to build (compile and package) **StartupFromScratch** for development and production.

## Prerequisites

- **Node.js** (v18+)
- **pnpm** (latest via Corepack)
- **TypeScript** v5.4.5 (configured in `package.json`)
- **Environment files**:
  - `.env-dev` (development), or
  - `.env-prod` (production)

## Build Script (`scripts/main/build.sh`)

All build logic is encapsulated in the main build script `scripts/main/build.sh`, which sources components from `scripts/build/` and `scripts/utils/`. It accepts a **production** flag (`-p` or `--production`) to switch environments.

### Usage

**Note:** To inject the project version into the Helm chart (Chart.yaml) and service tags (values-prod.yaml), supply the `--version` flag to `build.sh`. Without `--version`, build.sh uses the package.json version and will overwrite published Docker images with the same version if you're pushing to a registry.

```bash
# Development build (uses .env-dev; does NOT rewrite Helm charts)
bash scripts/main/build.sh

# Production build (uses .env-prod and rewrites Helm chart/appVersion and service tags)
bash scripts/main/build.sh --production --version "$(node -p 'require(\"./package.json\").version')"
```

### Script Workflow

1. **Load utilities** (`scripts/utils/*.sh`) and parse the production flag.
2. **Set `ENV_FILE`** to `.env-dev` or `.env-prod` and export it (using `scripts/utils/env.sh`).
3. **Clean**: remove previous `dist/` folders under each package (using `scripts/build/package.sh::clean_build`).
4. **Build Packages**: (using `scripts/build/package.sh::build_packages`)
   - Run Prisma Client generation.
   - Build the server package (`pnpm --filter @vrooli/server build`).
   - Build the UI package (`pnpm --filter @vrooli/ui build`).
5. **CLI Packaging** (placeholder, using `scripts/build/package.sh::package_cli`).
6. **Zip Artifacts** (using `scripts/build/zip.sh::zip_artifacts`):
   - Reads project version from `package.json`.
   - Copies each package's `dist/` folder into `/var/tmp/<version>/`.

Artifacts are now ready for deployment (e.g. `scripts/main/deploy.sh`) or manual distribution.

## Verifying the Build

After running `bash scripts/main/build.sh` (or `pnpm run build`):

```