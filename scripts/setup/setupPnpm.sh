#!/usr/bin/env bash
# Enable Corepack, activate pnpm, install dependencies, and generate the Prisma client.

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${HERE}/../utils/index.sh"

# Function to enable Corepack, install pnpm dependencies, and generate Prisma client
setup_pnpm() {
    header "🔧 Enabling Corepack and installing dependencies..."
    corepack enable
    corepack prepare pnpm@latest --activate

    info "Installing dependencies via pnpm..."
    pnpm install

    info "Generating Prisma client..."
    pnpm --filter @vrooli/prisma run generate
} 