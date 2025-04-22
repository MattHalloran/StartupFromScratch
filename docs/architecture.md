# Architecture

This document describes the high‑level architecture of **StartupFromScratch**, covering the monorepo layout, runtime services, and deployment considerations.

## Monorepo Structure

- **Package Manager:** Pnpm workspaces
- **Workspaces (`packages/`)**
  - `server`     – Express/Koa HTTP API in TypeScript
  - `prisma`  – Prisma schema, migrations, and client generation
  - `redis`   – Redis client helper module
  - `jobs`       – Background worker processes in TypeScript
  - `shared`     – Common utilities and types
  - `ui`         – React 18 + MUI web frontend (Vite) with SSR support (server- and client-entry scripts), using React Helmet to inject head tags from server-fetched SSO configuration

## Runtime Services

- **PostgreSQL** with vector extension: `ankane/pgvector:v0.4.4`
- **Redis**: `redis:7.4.0-alpine`
- **Node.js services** (server, jobs, ui) built on `node:18-alpine3.20`
- **Local mode** for `prisma`: uses SQLite (`schema.sqlite.prisma`)

## Docker Compose (Local Development)

The single `docker-compose.yml` file wires up all services:

```yaml
version: '3.8'
services:
  postgres:
    image: ankane/pgvector:v0.4.4
    env_file: ["${ENV_FILE:-.env-dev}"]
  redis:
    image: redis:7.4.0-alpine
    env_file: ["${ENV_FILE:-.env-dev}"]
  server:
    build: packages/server/Dockerfile
    env_file: ["${ENV_FILE:-.env-dev}"]
  jobs:
    build: packages/jobs/Dockerfile
    env_file: ["${ENV_FILE:-.env-dev}"]
  ui:
    build: packages/ui/Dockerfile
    env_file: ["${ENV_FILE:-.env-dev}"]
``` 

## Local vs. Container Mode

- The `scripts/develop.sh` script examines `USE_DOCKER`:  
  - **`USE_DOCKER=true`**: runs `docker-compose up`  
  - **`USE_DOCKER=false`**: runs TypeScript watchers for `server`, `jobs`, and `ui`, and links the appropriate Prisma schema (`.env-dev` vs `.env-prod` determines Postgres vs SQLite)

## Horizontal Scaling

- **Docker Compose**: use the `--scale` flag, e.g. `docker-compose up --scale server=3`  
- **Kubernetes**: deploy each service as a Deployment with multiple replicas and expose via a Service or Ingress

## Environments

- `.env-dev`    – local development  
- `.env-test`   – CI / test suite  
- `.env-prod`   – production deployments  

All env files share the same keys defined in `.env-example` (see `docs/setup.md`). 