#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# ——— Default values ——— #
# How the app will be run
TARGET="native-linux"
# Force "yes" to every confirmation
export YES="NO"
# The environment to run the setup for
ENVIRONMENT=${NODE_ENV:-development}
# Server location override (local|remote), determined if not set
LOCATION=""

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"
# shellcheck disable=SC1091
source "${HERE}/../develop/target/nativeLinux.sh"
# shellcheck disable=SC1091
source "${HERE}/../develop/target/nativeMac.sh"
# shellcheck disable=SC1091
source "${HERE}/../develop/target/nativeWin.sh"
# shellcheck disable=SC1091
source "${HERE}/../develop/target/dockerOnly.sh"
# shellcheck disable=SC1091
source "${HERE}/../develop/target/k8sCluster.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") \
  [-t|--target <env>] \
  [-h|--help] \
  [-p|--prod] \
  [-y|--yes] \
  [-l|--location <local|remote>]

Starts the development environment for the Vrooli project.

Options:
  -t, --target:                (native-linux|native-macos|docker|k8s) The environment to develop in
  -h, --help:                  Show this help message
  -p, --prod:                  Skips development-only steps and uses production environment variables
  -y, --yes:                   Automatically answer yes to all confirmation prompts
  -l, --location:              <local|remote> Override automatic server location detection
EOF

    print_exit_codes
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--target) TARGET="$2"; shift 2 ;;
            -p|--prod)   ENVIRONMENT="production"; shift ;;
            -y|--yes)    YES="YES";        shift ;;
            -l|--location) LOCATION="$2"; shift 2 ;;
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
    SETUP_ARGS=("--target" "$TARGET") # Use an array
    if is_yes "$YES"; then
        SETUP_ARGS+=("-y")
    fi
    if [ "$ENVIRONMENT" = "production" ]; then
        SETUP_ARGS+=("--prod")
    fi
    # shellcheck disable=SC1091
    source "${HERE}/../main/setup.sh" "${SETUP_ARGS[@]}" # Pass array elements as separate arguments

    load_secrets
    check_location_if_not_set

    if [[ "$LOCATION" == "remote" ]]; then
        setup_proxy
    fi

    # Run the development script for the target
    execute_for_target "$TARGET" "start_development_" || exit "${ERROR_USAGE}"

    success "✅ Development environment started." 
}

main "$@"
