#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${HERE}/../utils/index.sh"

header "Starting project setup..."

# Make scripts executable
source "${HERE}/../setup/setScriptPermissions.sh"
set_script_permissions

# Update apt-get
source "${HERE}/../setup/aptUpdate.sh"
run_apt_get_update_and_upgrade

# Install Bats and dependencies
source "${HERE}/../setup/setupBats.sh"
install_bats

# Enable pnpm via Corepack
info "Enabling Corepack and setting pnpm version..."
corepack enable
corepack prepare pnpm@latest --activate

info "Installing dependencies via pnpm..."
pnpm install

info "Generating Prisma client..."
pnpm --filter @vrooli/prisma run generate

info "Copying environment variables file..."
if [ ! -f .env-dev ]; then
  cp .env-example .env-dev
  info "Created .env-dev from .env-example"
else
  info ".env-dev already exists, skipping copy"
fi

success "Setup complete. You can now run 'pnpm run develop' or 'bash scripts/main/develop.sh'" 