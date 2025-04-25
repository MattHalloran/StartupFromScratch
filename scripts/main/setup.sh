#!/usr/bin/env bash
set -euo pipefail

# Changed to export since it's used in other scripts
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# ——— Default values ——— #
# How the app will be run
TARGET="native-linux"
# Remove previous artefacts (volumes, ~/.pnpm‑store, etc.)
CLEAN="NO"
# The environment to run the setup for
ENVIRONMENT=${NODE_ENV:-development}
# Where to load secrets/env variables from
export SECRETS_SOURCE="env"
# Skip prompts, avoid tools not needed in CI
export CI="NO"
# Force "yes" to every confirmation
export YES="NO"
# Server location override (local|remote), determined if not set
export SERVER_LOCATION=""
# What to do when encountering sudo commands without elevated privileges
export SUDO_MODE="error"

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/index.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/target/index.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") \
  [-t|--target <env>] \
  [-h|--help] \
  [--clean] \
  [--ci-cd] \
  [--secrets-source <env|vault>] \
  [--sudo-mode <error|skip>] \
  [--prod] \
  [-y|--yes] \
  [--location|--server-location <local|remote>]

Prepares the project for development or production.

Options:
  -t, --target:                   (native-linux|native-macos|docker|k8s) The environment to run the setup for
  -h, --help:                     Show this help message
  --clean:                        Remove previous artefacts (volumes, ~/.pnpm-store, etc.)
  --ci-cd:                        Configure the system for CI/CD (via GitHub Actions)
  --secrets-source:               (env|vault) Where to load secrets/env variables from
  --sudo-mode:                    (error|skip) What to do when encountering sudo commands without elevated privileges
  -p, --prod:                     Skips development-only steps and uses production environment variables
  -y, --yes:                      Automatically answer yes to all confirmation prompts
  --location, --server-location:  (local|remote) Override automatic server location detection

EOF

    print_exit_codes
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--target)                  TARGET="$2"; shift 2 ;;
            --clean)                      CLEAN="YES";      shift ;;
            --ci)                         CI="YES";         shift ;;
            --secrets-source)             SECRETS_SOURCE="$2"; shift 2 ;;
            --sudo-mode)                  SUDO_MODE="$2";   shift 2 ;;
            -p|--prod)                    ENVIRONMENT="production"; shift ;;
            -y|--yes)                     YES="YES";        shift ;;
            --location|--server-location) SERVER_LOCATION="$2"; shift 2 ;;
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
    check_location_if_not_set

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
    execute_for_target "$TARGET" "setup_" || exit "${ERROR_USAGE}"
    success "✅ Setup complete. You can now run 'pnpm run develop' or 'bash scripts/main/develop.sh'" 
}

main "$@"