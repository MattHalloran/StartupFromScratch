#!/usr/bin/env bash
# Enable Corepack, activate pnpm, install dependencies, and generate the Prisma client.
set -euo pipefail

SETUP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/locations.sh"
# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/log.sh"
# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/system.sh"

pnpm_tools::generate_prisma_client() {
    HASH_FILE="${DATA_DIR}/schema-hash"

    # Compute current schema hash
    if system::is_command "shasum"; then
        CURRENT_HASH=$(shasum -a 256 "$DB_SCHEMA_FILE" | awk '{print $1}')
    elif system::is_command "sha256sum"; then
        CURRENT_HASH=$(sha256sum "$DB_SCHEMA_FILE" | awk '{print $1}')
    else
        log::error "Neither shasum nor sha256sum found; cannot compute schema hash"
        exit 1
    fi

    # Read previous hash (if any)
    PREV_HASH=""
    if [ -f "$HASH_FILE" ]; then
        PREV_HASH=$(cat "$HASH_FILE")
    fi

    # Compare and decide whether to regenerate
    if [ "$CURRENT_HASH" = "$PREV_HASH" ]; then
        log::info "Schema unchanged; skipping Prisma client generation"
    else
        log::info "Schema changed; generating Prisma client..."
        pnpm --filter @vrooli/prisma run generate
        mkdir -p "$HASH_DIR"
        echo "$CURRENT_HASH" > "$HASH_FILE"
    fi
}

# Function to enable Corepack, install pnpm dependencies, and generate Prisma client
pnpm_tools::setup() {
    log::header "🔧 Enabling Corepack and installing dependencies..."
    corepack enable
    corepack prepare pnpm@latest --activate

    log::info "Installing dependencies via pnpm..."
    { unset CI; pnpm install; }

    # Generate Prisma client if (and only if) the schema changed
    pnpm_tools::generate_prisma_client
}