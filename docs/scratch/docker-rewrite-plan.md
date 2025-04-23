# Docker Rewrite Plan

This document outlines the approach we are taking to overhaul the Docker-based development & build setup for the Vrooli monorepo.

## Goals
- Replace per-package Dockerfiles with a single multi-stage `Dockerfile` at the project root.  
- Leverage BuildKit cache mounts (`pnpm fetch` + `--mount=type=cache`) to speed up installs.  
- Produce lean images for `server`, `jobs`, and a `ui-dev` development container.  
- Update `docker-compose.yml` to use build targets and remove clobbering volume mounts.  

## Steps Taken

1. **Root `Dockerfile`**  
   - **Base**: Installs pnpm via Corepack, primes cache, installs all workspace deps, builds all packages.  
   - **server**: Copies only production artifacts + deps, exposes port 4000.  
   - **jobs**: Copies only compiled job artifacts + deps.  
   - **ui-dev**: Uses the same build but runs `pnpm --filter @vrooli/ui run dev` on `0.0.0.0:3000` for live reloading.

2. **`docker-compose.yml`**  
   - Repoints `server`, `jobs`, `ui` to use the new root `Dockerfile` with `target: server|jobs|ui-dev`.  
   - Retains `postgres` & `redis` definitions unchanged.  
   - Removes old `volumes` mounts for source directories to prevent build clobber.

3. **Clean-up**  
   - Remove outdated per-package Dockerfiles in `packages/server`, `packages/jobs`, and `packages/ui`.

## Next Steps
- Developers can now run `bash scripts/main/develop.sh --target docker` to spin up `postgres`, `redis`, `server`, `jobs`, and `ui-dev` (Vite) all via Docker.  
- If desired, a `docker-compose.prod.yml` and `ui-prod` target can be added later for production-stage deployments.  
- Monitor build times & image sizes; tweak cache mount IDs or stage splits as necessary. 