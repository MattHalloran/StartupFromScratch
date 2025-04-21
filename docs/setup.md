# Environment Setup

This guide explains how to configure environment variables for **development**, **testing**, and **production**, and how to use the lifecycle scripts.

## Environment Files

We provide a template of all required variables in:

  .env-example

This file is committed and shows the keys you must set. Actual environment files should **not** be committed and are ignored by Git:

  .env-dev    # development settings
  .env-test   # test suite settings
  .env-prod   # production settings

### Creating Your Env Files

1. Copy the example to `.env-dev` and set your local development values:
   ```bash
   cp .env-example .env-dev
   # edit .env-dev as needed
   ```

2. Copy for testing:
   ```bash
   cp .env-example .env-test
   # adjust DATABASE_URL, REDIS_URL for test instances
   ```

3. Copy for production:
   ```bash
   cp .env-example .env-prod
   # fill in production DB credentials, API endpoints, etc.
   ```

## scripts/utils.sh

Contains common helpers sourced by all scripts:

```bash
# is_yes: returns true if argument is y, yes, true, or 1 (case-insensitive)
is_yes() {
  case "${1,,}" in
    y|yes|true|1) return 0;;
    *) return 1;;
  esac
}
```

## Script Usage

All lifecycle scripts accept a **production** flag (either `-p` or `--production`) to switch between `.env-dev` and `.env-prod`.

### Development

```bash
# Docker-backed (default .env-dev)
bash scripts/develop.sh

# Production-mode (uses .env-prod)
bash scripts/develop.sh --production
```

### Build

```bash
# Development build (default .env-dev)
bash scripts/build.sh

# Production build (uses .env-prod)
bash scripts/build.sh -p
```

### Deploy

```bash
# Deploy to staging (default .env-dev)
bash scripts/deploy.sh staging

# Deploy to production (uses .env-prod)
bash scripts/deploy.sh production
# or
bash scripts/deploy.sh --production
```

--- 