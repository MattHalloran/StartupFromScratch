#!/usr/bin/env bash
set -euo pipefail

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${HERE}/../utils/index.sh"

# ——— Default values ——— #
# How the app will be run
TARGET="native-linux"
# Force "yes" to every confirmation
YES="NO"
# The environment to run the setup for
ENVIRONMENT=${NODE_ENV:-development}

usage() {
    cat <<EOF
Usage: $(basename "$0") --target <env> [-h | --help] [--prod] [-y | --yes]

Starts the development environment for the Vrooli project.

Options:
  --target:                (native-linux|native-macos|docker|k8s) The environment to develop in
  -h, --help:              Show this help message
  --prod:                  Skips development-only steps and uses production environment variables
  -y, --yes:               Automatically answer yes to all confirmation prompts

EOF

    print_exit_codes
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target) TARGET="$2"; shift 2 ;;
            --prod)   ENVIRONMENT="production"; shift ;;
            -y|--yes)    YES="YES";        shift ;;
            -h|--help)
                usage
                exit "$ERROR_USAGE"
                ;;
            *)
                echo "Unknown flag $1"
                usage
                exit "$ERROR_USAGE"
                ;;
        esac
    done
    # Ensure TARGET is set
    if [[ -z "$TARGET" ]]; then
        usage
        exit "$ERROR_USAGE"
    fi
    # Return success to prevent set -e from aborting on non-zero test
    return 0
}

main() {
    header "🏃 Starting development environment..."
    parse_arguments "$@"

    # Run the setup script for the target and environment
    SETUP_ARGS="--target $TARGET"
    if is_yes "$YES"; then
        SETUP_ARGS="$SETUP_ARGS -y"
    fi
    if [ "$ENVIRONMENT" = "production" ]; then
        SETUP_ARGS="$SETUP_ARGS --prod"
    fi
    source "${HERE}/../main/setup.sh" $SETUP_ARGS

    # Run the development script for the target
    case "$TARGET" in
        l|nl|linux|native-linux) source "${HERE}/../develop/target/nativeLinux.sh" ; start_development_native_linux ;;
        m|nm|mac|native-mac)   source "${HERE}/../develop/target/nativeMac.sh" ; start_development_native_mac ;;
        w|nw|win|native-win)   source "${HERE}/../develop/target/nativeWin.sh" ; start_development_native_win ;;
        d|dc|docker|docker-compose) source "${HERE}/../develop/target/dockerOnly.sh" ; start_development_docker_only ;;
        k|kc|k8s|kubernetes)          source "${HERE}/../develop/target/k8sCluster.sh" ; start_development_k8s_cluster ;;
        *) echo "Bad --target"; exit ${ERROR_USAGE} ;;
    esac

    success "✅ Development environment started." 
}

main "$@"


# #!/usr/bin/env bash
# set -e

# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# # Load utility functions
# source "$SCRIPT_DIR/../utils/logging.sh"
# source "$SCRIPT_DIR/../utils/env.sh"

# # Load development component functions (only need setup_local_env and start_docker_db)
# source "$SCRIPT_DIR/../develop/docker.sh"
# source "$SCRIPT_DIR/../develop/local.sh"

# # Default env file to dev
# production=0
# # Parse flags
# while [[ "$#" -gt 0 ]]; do
#   case "$1" in
#     -p|--production)
#       production=1; shift;;
#     *)
#       shift;;
#   esac
# done

# # Pick environment file
# ENV_FILE=$(get_env_file "$production")
# # Don't export globally yet, only pass specifically if needed

# USE_DOCKER=${USE_DOCKER:-true}

# # Default DB type based on Docker usage
# if [ "$USE_DOCKER" != "true" ]; then
#   DB_TYPE=${DB_TYPE:-sqlite}
# else
#   DB_TYPE=${DB_TYPE:-postgres}
# fi

# log_info "Starting development environment (Production: $production, Docker: $USE_DOCKER, DB: $DB_TYPE)"

# # Start DB containers if requested
# if [ "$USE_DOCKER" = "true" ]; then
#   start_docker_db "$ENV_FILE"
# fi

# # Setup local env (linking schema, etc.)
# setup_local_env "$DB_TYPE"

# # Perform initial build for server and jobs using pnpm exec
# log_info "Performing initial build for server and jobs..."
# # Unset ENV_FILE just in case it interferes with tsc PnP resolution
# # unset ENV_FILE # Temporarily commented out - let's try without first
# pnpm exec tsc -b packages/server
# pnpm exec tsc -b packages/jobs

# # Now export ENV_FILE for the concurrently processes
# export ENV_FILE

# # Start watcher/dev processes concurrently
# log_info "Starting watchers and dev servers (server, jobs, UI)..."
# pnpm exec concurrently --names "TSC-SVR,TSC-JOB,NODE-SVR,NODE-JOB,UI" -c "yellow,blue,magenta,cyan,green" \
#   "pnpm exec tsc -b packages/server --watch --preserveWatchOutput" \
#   "pnpm exec tsc -b packages/jobs --watch --preserveWatchOutput" \
#   "pnpm exec node --watch packages/server/dist/index.js" \
#   "pnpm exec node --watch packages/jobs/dist/index.js" \
#   "pnpm --filter @vrooli/ui run dev -- --port 3000"

# log_success "Development environment running (concurrently). Monitor logs above." 