#!/usr/bin/env bash

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COMPOSE_DIR=$(cd "$HERE"/../../.. && pwd)
source "${HERE}/../../utils/index.sh"

start_development_native_linux() {
    header "🚀 Starting native Linux development environment..."
    cd "$COMPOSE_DIR"

    cleanup() {
        info "🔧 Cleaning up development environment at $COMPOSE_DIR..."
        cd "$COMPOSE_DIR"
        docker-compose down
        cd "$ORIGINAL_DIR"
        exit 0
    }
    trap cleanup SIGINT SIGTERM

    info "Starting database containers (Postgres and Redis)..."
    docker-compose up -d postgres redis

    info "Starting watchers and development servers (server, jobs, UI)..."
    pnpm exec concurrently --names "TSC-SVR,TSC-JOB,NODE-SVR,NODE-JOB,UI" -c "yellow,blue,magenta,cyan,green" \
        "pnpm exec tsc -b packages/server --watch --preserveWatchOutput" \
        "pnpm exec tsc -b packages/jobs --watch --preserveWatchOutput" \
        "pnpm exec node --watch packages/server/dist/index.js" \
        "pnpm exec node --watch packages/jobs/dist/index.js" \
        "pnpm --filter @vrooli/ui run dev -- --port 3000"
}
