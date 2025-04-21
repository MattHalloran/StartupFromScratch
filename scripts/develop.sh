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

if [ "$USE_DOCKER" = "true" ]; then
  echo "⚙️  Starting development with Docker using $ENV_FILE..."
  ENV_FILE="$ENV_FILE" docker-compose up --build
else
  echo "⚙️  Starting development without Docker using $ENV_FILE..."
  # Link appropriate Prisma schema
  if [ "$DB_TYPE" = "sqlite" ]; then
    ln -sf prisma/schema.sqlite.prisma packages/prisma-db/prisma/schema.prisma
  else
    ln -sf prisma/schema.postgres.prisma packages/prisma-db/prisma/schema.prisma
  fi

  echo "🚀  Running all services..."
  ENV_FILE="$ENV_FILE" yarn workspace @startupfromscratch/server dev &
  ENV_FILE="$ENV_FILE" yarn workspace @startupfromscratch/jobs dev &
  ENV_FILE="$ENV_FILE" yarn workspace @startupfromscratch/ui dev &
  wait
fi 