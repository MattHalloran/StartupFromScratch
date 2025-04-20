#!/usr/bin/env bash
set -e

USE_DOCKER=${USE_DOCKER:-true}

if [ "$USE_DOCKER" = "true" ]; then
  echo "⚙️  Starting development with Docker..."
  docker-compose up --build
else
  echo "⚙️  Starting development without Docker..."
  # Link appropriate Prisma schema
  if [ "$DB_TYPE" = "sqlite" ]; then
    ln -sf prisma/schema.sqlite.prisma packages/prisma-db/prisma/schema.prisma
  else
    ln -sf prisma/schema.postgres.prisma packages/prisma-db/prisma/schema.prisma
  fi

  echo "🚀  Running all services..."
  yarn workspace @startupfromscratch/server dev &
  yarn workspace @startupfromscratch/jobs dev &
  yarn workspace @startupfromscratch/ui dev &
  wait
fi 