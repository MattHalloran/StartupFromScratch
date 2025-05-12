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

# Ensure pnpm is available, using corepack if possible, otherwise fallback to npm install -g pnpm
pnpm_tools::ensure_pnpm() {
    # Try to use corepack if available and pnpm is available after activation
    if system::is_command "corepack"; then
        corepack enable || true
        corepack prepare pnpm@latest --activate || true
    fi

    # If pnpm is still not available, install it locally for the user
    if ! system::is_command "pnpm"; then
        echo "pnpm not found, installing locally via npm..."
        export PNPM_HOME="$HOME/.pnpm"
        mkdir -p "$PNPM_HOME"
        npm install --prefix "$PNPM_HOME" pnpm

        # Try to find the pnpm binary
        if [ -f "$PNPM_HOME/bin/pnpm" ]; then
            export PATH="$PNPM_HOME/bin:$PATH"
        else
            # Fallback: use npx for all pnpm commands
            alias pnpm="npx --prefix $PNPM_HOME pnpm"
        fi
    fi

    # Final check: try to run pnpm --version (using alias if set)
    if ! pnpm --version >/dev/null 2>&1; then
        log::error "pnpm is still not available after attempted install. Exiting."
        exit 1
    fi
}

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
        mkdir -p "$DATA_DIR"
        echo "$CURRENT_HASH" > "$HASH_FILE"
    fi
}

# Function to enable Corepack, install pnpm dependencies, and generate Prisma client
pnpm_tools::setup() {
    log::header "🔧 Enabling Corepack and installing dependencies..."
    pnpm_tools::ensure_pnpm

    log::info "Installing dependencies via pnpm..."
    pnpm install

    # Generate Prisma client if (and only if) the schema changed
    pnpm_tools::generate_prisma_client
}