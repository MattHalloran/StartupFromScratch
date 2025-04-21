#!/usr/bin/env bash
set -e

# Load utility functions
source "$(dirname "$0")/utils.sh"

# Default env file to dev
production=0
# Parse flags
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -p|--production)
      production=1; shift;;
    *)
      shift;;
  esac
done

# Pick environment file
if is_yes "$production"; then
  ENV_FILE=.env-prod
else
  ENV_FILE=.env-dev
fi
export ENV_FILE

USE_DOCKER=${USE_DOCKER:-true}

# Default to SQLite for native development when not using Docker
if [ "$USE_DOCKER" != "true" ]; then
  DB_TYPE=${DB_TYPE:-sqlite}
fi

# Start DB containers if requested
if [ "$USE_DOCKER" = "true" ]; then
  echo "⚙️  Starting Docker containers for Postgres and Redis using $ENV_FILE..."
  ENV_FILE="$ENV_FILE" docker-compose up -d postgres redis
fi

echo "🚀  Running services locally (server, jobs, UI)..."
# Link appropriate Prisma schema based on DB_TYPE (defaults to Postgres if unset)
if [ "$DB_TYPE" = "sqlite" ]; then
  ln -sf prisma/schema.sqlite.prisma packages/prisma-db/prisma/schema.prisma
else
  ln -sf prisma/schema.postgres.prisma packages/prisma-db/prisma/schema.prisma
fi

# Start TS dev servers for each workspace
ENV_FILE="$ENV_FILE" yarn workspace @startupfromscratch/server dev &
ENV_FILE="$ENV_FILE" yarn workspace @startupfromscratch/jobs dev &
ENV_FILE="$ENV_FILE" yarn workspace @startupfromscratch/ui dev &
wait 