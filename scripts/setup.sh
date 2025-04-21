#!/usr/bin/env bash
set -e

# Enable Yarn v4 (Berry)
corepack enable
corepack prepare yarn@4.0.0 --activate

echo "Installing dependencies..."
yarn install

echo "Generating Prisma client..."
yarn workspace @startupfromscratch/prisma-db generate

echo "Copying environment variables file..."
if [ ! -f .env-dev ]; then
  cp .env-example .env-dev
  echo "Created .env-dev from .env-example"
else
  echo ".env-dev already exists, skipping copy"
fi

echo "Setup complete. You can now run 'yarn develop' or 'bash scripts/develop.sh'" 