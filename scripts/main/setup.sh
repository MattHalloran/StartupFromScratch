#!/usr/bin/env bash
set -euo pipefail
DESCRIPTION="Prepares the project for development or production."

# Changed to export since it's used in other scripts
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/index.sh"
# shellcheck disable=SC1091
source "${HERE}/../setup/target/index.sh"

parse_arguments() {
    arg_reset

    arg_register_help
    arg_register_secrets_source
    arg_register_sudo_mode
    arg_register_yes
    arg_register_location
    arg_register_environment
    arg_register_target

    arg_register \
        --name "clean" \
        --flag "c" \
        --desc "Remove previous artefacts (volumes, ~/.pnpm-store, etc.)" \
        --type "value" \
        --options "yes|no" \
        --default "no"

    arg_register \
        --name "ci-cd" \
        --flag "d" \
        --desc "Configure the system for CI/CD (via GitHub Actions)" \
        --type "value" \
        --options "yes|no" \
        --default "no"

    if is_asking_for_help "$@"; then
        arg_usage "$DESCRIPTION"
        print_exit_codes
        exit 0
    fi

    arg_parse "$@" >/dev/null
    
    export TARGET=$(arg_get "target")
    export CLEAN=$(arg_get "clean")
    export CI=$(arg_get "ci-cd")
    export SECRETS_SOURCE=$(arg_get "secrets-source")
    export SUDO_MODE=$(arg_get "sudo-mode")
    export YES=$(arg_get "yes")
    export LOCATION=$(arg_get "location")
    export ENVIRONMENT=$(arg_get "environment")
}

main() {
    parse_arguments "$@"
    header "🔨 Starting project setup for $(match_target "$TARGET")..."

    # Prepare the system
    set_script_permissions
    fix_system_clock
    check_internet
    run_system_update_and_upgrade

    # Clean up volumes & caches
    if is_yes "$CLEAN"; then
        clean
    fi
    load_secrets
    check_location_if_not_set

    if [[ "$LOCATION" == "remote" ]]; then
        purge_apt_update_notifier
        # Check and free necessary ports to avoid port-in-use errors on remote
        # (Postgres 5432, Redis 6379, UI 3000, Server 4000)
        check_and_free_port 5432
        check_and_free_port 6379
        check_and_free_port 3000
        check_and_free_port 4000
        setup_reverse_proxy
    fi

    setup_firewall
    echo "target f: $TARGET"
    if [[ "$ENVIRONMENT" == "development" ]]; then
        install_bats
        install_shellcheck
    fi

    # Run the setup script for the target
    execute_for_target "$TARGET" "setup_" || exit "${ERROR_USAGE}"
    success "✅ Setup complete. You can now run 'pnpm run develop' or 'bash scripts/main/develop.sh'"
}

main "$@"