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
