#!/usr/bin/env bash
set -euo pipefail

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

source "${HERE}/../utils/index.sh"
source "${HERE}/../setup/setScriptPermissions.sh"
source "${HERE}/../setup/time.sh"
source "${HERE}/../setup/checkInternet.sh"
source "${HERE}/../setup/clean.sh"
source "${HERE}/../setup/setupFirewall.sh"
source "${HERE}/../setup/setupBats.sh"
source "${HERE}/../setup/setupShellcheck.sh"

# ——— Default values ——— #
# How the app will be run
TARGET="native-linux"
# Where to load secrets/env variables from
SECRETS_SOURCE="env"
# Remove previous artefacts (volumes, ~/.pnpm‑store, etc.)
CLEAN="NO"
# Skip prompts, avoid tools not needed in CI
CI="NO"
# Force "yes" to every confirmation
YES="NO"
# The environment to run the setup for
ENVIRONMENT=${NODE_ENV:-development}

usage() {
    cat <<EOF
Usage: $(basename "$0") --target <env> [-h | --help] [--clean] [--ci-cd] [--secrets-source <env|vault>] [--prod] [-y | --yes]

Prepares the project for development or production.

Options:
  --target:                (native-linux|native-macos|docker|k8s) The environment to run the setup for
  -h, --help:              Show this help message
  --clean:                 Remove previous artefacts (volumes, ~/.pnpm-store, etc.)
  --ci-cd:                 Configure the system for CI/CD (via GitHub Actions)
  --secrets-source:        (env|vault) Where to load secrets/env variables from
  --prod:                  Skips development-only steps and uses production environment variables
  -y, --yes:               Automatically answer yes to all confirmation prompts

EOF

    print_exit_codes
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target) TARGET="$2"; shift 2 ;;
            --clean)  CLEAN="YES";      shift ;;
            --ci)     CI="YES";         shift ;;
            --secrets-source) SECRETS_SOURCE="$2"; shift 2 ;;
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

# Setup steps only needed during development
setup_dev() {
    install_bats
    install_shellcheck
}

main() {
    header "🔨 Starting project setup..."
    parse_arguments "$@"

    set_script_permissions
    fix_system_clock
    check_internet
    run_system_update_and_upgrade

    # Clean up volumes & caches
    if is_yes "$CLEAN" && confirm "Prune volumes, caches, and other build artifacts?"; then
        clean
    fi

    load_secrets

    # Determine where this script is running (local or remote)
    export SERVER_LOCATION=$("${HERE}/domainCheck.sh" $SITE_IP $API_URL | tail -n 1)

    setup_firewall

    if [[ "$ENVIRONMENT" == "development" ]]; then
        setup_dev
    fi

    # info "Copying environment variables file..."
    # if [ ! -f .env-dev ]; then
    # cp .env-example .env-dev
    # info "Created .env-dev from .env-example"
    # else
    # info ".env-dev already exists, skipping copy"
    # fi

    # Run the setup script for the target
    case "$TARGET" in
        l|nl|linux|native-linux) source "${HERE}/../setup/target/nativeLinux.sh" ; setup_native_linux ;;
        m|nm|mac|native-mac)   source "${HERE}/../setup/target/nativeMac.sh" ; setup_native_mac ;;
        w|nw|win|native-win)   source "${HERE}/../setup/target/nativeWin.sh" ; setup_native_win ;;
        d|dc|docker|docker-compose) source "${HERE}/../setup/target/dockerOnly.sh" ; setup_docker_only ;;
        k|kc|k8s|kubernetes)          source "${HERE}/../setup/target/k8sCluster.sh" ; setup_k8s_cluster ;;
        *) echo "Bad --target"; exit ${ERROR_USAGE} ;;
    esac
    success "✅ Setup complete. You can now run 'pnpm run develop' or 'bash scripts/main/develop.sh'" 
}

main "$@"