#!/usr/bin/env bash
# Enable Corepack, activate pnpm, install dependencies, and generate the Prisma client.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"

# Function to enable Corepack, install pnpm dependencies, and generate Prisma client
setup_pnpm() {
    header "🔧 Enabling Corepack and installing dependencies..."
    corepack enable
    corepack prepare pnpm@latest --activate

    info "Installing dependencies via pnpm..."
    { unset CI; pnpm install; }

    # Generate Prisma client if (and only if) the schema changed
    generate_prisma_client
}

# Function to generate Prisma client only when the schema changes
generate_prisma_client() {
    SCHEMA_PATH="${HERE}/../../packages/server/src/db/schema.prisma"
    HASH_DIR="${HERE}/../../data"
    HASH_FILE="${HASH_DIR}/schema-hash"

    # Compute current schema hash
    if command -v shasum >/dev/null 2>&1; then
        CURRENT_HASH=$(shasum -a 256 "$SCHEMA_PATH" | awk '{print $1}')
    elif command -v sha256sum >/dev/null 2>&1; then
        CURRENT_HASH=$(sha256sum "$SCHEMA_PATH" | awk '{print $1}')
    else
        echo "Error: Neither shasum nor sha256sum found; cannot compute schema hash" >&2
        exit 1
    fi

    # Read previous hash (if any)
    PREV_HASH=""
    if [ -f "$HASH_FILE" ]; then
        PREV_HASH=$(cat "$HASH_FILE")
    fi

    # Compare and decide whether to regenerate
    if [ "$CURRENT_HASH" = "$PREV_HASH" ]; then
        info "Schema unchanged; skipping Prisma client generation"
    else
        info "Schema changed; generating Prisma client..."
        pnpm --filter @vrooli/prisma run generate
        mkdir -p "$HASH_DIR"
        echo "$CURRENT_HASH" > "$HASH_FILE"
    fi
} 