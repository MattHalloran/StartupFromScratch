#!/usr/bin/env bash
set -euo pipefail

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${HERE}/../utils/index.sh"

# ——— Default values ——— #
# How the app will be run
TARGET="native-linux"
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
Usage: $(basename "$0") --target <env> [-h | --help] [--clean] [--ci-cd] [--env-secrets-setup] [--prod] [-y | --yes]

Prepares the project for development or production.

Options:
  --target:                (native-linux|native-macos|docker-compose|kubernetes) The environment to run the setup for
  -h, --help:              Show this help message
  --clean:                 Remove previous artefacts (volumes, ~/.pnpm-store, etc.)
  --ci-cd:                 Configure the system for CI/CD (via GitHub Actions)
  --env-secrets-setup:     Adds secret files to the vault
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
            --env-secrets-setup) ENV_FILES_SET_UP="YES"; shift ;;
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
    header "🔨 Starting project setup..."
    parse_arguments "$@"

    # Make scripts executable
    source "${HERE}/../setup/setScriptPermissions.sh"
    set_script_permissions

    # Fix system clock
    source "${HERE}/../setup/time.sh"
    fix_system_clock

    # Check internet connection
    source "${HERE}/../setup/checkInternet.sh"
    check_internet

    # Update apt-get
    source "${HERE}/../setup/aptUpdate.sh"
    run_apt_get_update_and_upgrade

    # Clean up volumes & caches
    if is_yes "$CLEAN" && confirm "Prune volumes, caches, and other build artifacts?"; then
        source "${HERE}/../setup/clean.sh"
        clean
    fi

    # Install Bats and dependencies
    source "${HERE}/../setup/setupBats.sh"
    install_bats

    # Load environment variables
    load_env_file "$ENVIRONMENT"

    # info "Copying environment variables file..."
    # if [ ! -f .env-dev ]; then
    # cp .env-example .env-dev
    # info "Created .env-dev from .env-example"
    # else
    # info ".env-dev already exists, skipping copy"
    # fi

    # Run the setup script for the target
    case "$TARGET" in
        native-linux) source "${HERE}/../setup/target/nativeLinux.sh" ; setup_native_linux ;;
        native-mac)   source "${HERE}/../setup/target/nativeMac.sh" ; setup_native_mac ;;
        native-win)   source "${HERE}/../setup/target/nativeWin.sh" ; setup_native_win ;;
        docker)       source "${HERE}/../setup/target/dockerOnly.sh" ; setup_docker_only ;;
        k8s)          source "${HERE}/../setup/target/k8sCluster.sh" ; setup_k8s_cluster ;;
        *) echo "Bad --target"; exit ${ERROR_USAGE} ;;
    esac
    success "✅ Setup complete. You can now run 'pnpm run develop' or 'bash scripts/main/develop.sh'" 
}

main "$@"