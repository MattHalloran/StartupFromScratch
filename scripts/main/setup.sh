#!/usr/bin/env bash
set -euo pipefail

# Changed to export since it's used in other scripts
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/setScriptPermissions.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/time.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/checkInternet.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/clean.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/setupFirewall.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/setupBats.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/setupShellcheck.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/target/nativeLinux.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/target/nativeMac.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/target/nativeWin.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/target/dockerOnly.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/target/k8sCluster.sh"

# ——— Default values ——— #
# How the app will be run
TARGET="native-linux"
# Where to load secrets/env variables from
export SECRETS_SOURCE="env"
# Remove previous artefacts (volumes, ~/.pnpm‑store, etc.)
CLEAN="NO"
# Skip prompts, avoid tools not needed in CI
export CI="NO"
# Force "yes" to every confirmation
export YES="NO"
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
    # Fix SC2155 by separating declaration and assignment
    local server_location
    server_location=$("${HERE}/domainCheck.sh" "$SITE_IP" "$API_URL" | tail -n 1)
    export SERVER_LOCATION="$server_location"

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