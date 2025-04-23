#!/usr/bin/env bash

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${HERE}/../utils/index.sh"

# Sets up the local environment (non-Docker)
setup_local_env() {
  local db_type="$1"
  info "Setting up local development environment..."

  # Link appropriate Prisma schema
  info "Linking Prisma schema for $db_type..."
  # Note: Relative paths assume script is run from project root
  if [ "$db_type" = "sqlite" ]; then
    ln -sf ../../packages/prisma/prisma/schema.sqlite.prisma packages/prisma/prisma/schema.prisma
  else
    ln -sf ../../packages/prisma/prisma/schema.postgres.prisma packages/prisma/prisma/schema.prisma
  fi

  # Run migrations if necessary (example for SQLite)
  if [ "$db_type" = "sqlite" ]; then
    info "Running SQLite migrations..."
    # Add migration command here if needed, e.g.:
    # pnpm --filter @vrooli/prisma run dev -- --name init_sqlite
  fi
}

# This function is no longer used directly by develop.sh
# Kept here for potential future use or direct invocation
start_local_servers_concurrently() {
  info "Starting local development servers (server, jobs, UI) using concurrently..."
  npx concurrently --names "SERVER,JOBS,UI" -c "bgBlue.bold,bgMagenta.bold,bgGreen.bold" \
    "pnpm --filter @vrooli/server run dev" \
    "pnpm --filter @vrooli/jobs run dev" \
    "pnpm --filter @vrooli/ui run dev"
} 