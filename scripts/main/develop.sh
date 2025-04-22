#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Load utility functions
source "$SCRIPT_DIR/../utils/logging.sh"
source "$SCRIPT_DIR/../utils/env.sh"

# Load development component functions (only need setup_local_env and start_docker_db)
source "$SCRIPT_DIR/../develop/docker.sh"
source "$SCRIPT_DIR/../develop/local.sh"

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
ENV_FILE=$(get_env_file "$production")
# Don't export globally yet, only pass specifically if needed

USE_DOCKER=${USE_DOCKER:-true}

# Default DB type based on Docker usage
if [ "$USE_DOCKER" != "true" ]; then
  DB_TYPE=${DB_TYPE:-sqlite}
else
  DB_TYPE=${DB_TYPE:-postgres}
fi

log_info "Starting development environment (Production: $production, Docker: $USE_DOCKER, DB: $DB_TYPE)"

# Start DB containers if requested
if [ "$USE_DOCKER" = "true" ]; then
  start_docker_db "$ENV_FILE"
fi

# Setup local env (linking schema, etc.)
setup_local_env "$DB_TYPE"

# Perform initial build for server and jobs using pnpm exec
log_info "Performing initial build for server and jobs..."
# Unset ENV_FILE just in case it interferes with tsc PnP resolution
# unset ENV_FILE # Temporarily commented out - let's try without first
pnpm exec tsc -b packages/server
pnpm exec tsc -b packages/jobs

# Now export ENV_FILE for the concurrently processes
export ENV_FILE

# Start watcher/dev processes concurrently
log_info "Starting watchers and dev servers (server, jobs, UI)..."
pnpm exec concurrently --names "TSC-SVR,TSC-JOB,NODE-SVR,NODE-JOB,UI" -c "yellow,blue,magenta,cyan,green" \
  "pnpm exec tsc -b packages/server --watch --preserveWatchOutput" \
  "pnpm exec tsc -b packages/jobs --watch --preserveWatchOutput" \
  "pnpm exec node --watch packages/server/dist/index.js" \
  "pnpm exec node --watch packages/jobs/dist/index.js" \
  "pnpm --filter @vrooli/ui run dev -- --port 3000"

log_success "Development environment running (concurrently). Monitor logs above." 