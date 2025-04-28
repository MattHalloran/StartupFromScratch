#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"
# shellcheck disable=SC1091
source "${HERE}/../develop/index.sh"
# shellcheck disable=SC1091
source "${HERE}/../develop/target/index.sh"

parse_arguments() {
    arg_reset

    arg_register_help
    arg_register_secrets_source
    arg_register_sudo_mode
    arg_register_yes
    arg_register_location
    arg_register_environment
    arg_register_target

    if is_asking_for_help "$@"; then
        arg_usage "$DESCRIPTION"
        print_exit_codes
        exit 0
    fi

    arg_parse "$@" >/dev/null

    export TARGET=$(arg_get "target")
    export SECRETS_SOURCE=$(arg_get "secrets-source")
    export SUDO_MODE=$(arg_get "sudo-mode")
    export YES=$(arg_get "yes")
    export LOCATION=$(arg_get "location")
    export ENVIRONMENT=$(arg_get "environment")
}

main() {
    header "🏃 Starting development environment..."
    parse_arguments "$@"

    source "${HERE}/../main/setup.sh" "$@"

    if [[ "$LOCATION" == "remote" ]]; then
        setup_proxy
    fi

    # Run the development script for the target
    execute_for_target "$TARGET" "start_development_" || exit "${ERROR_USAGE}"

    success "✅ Development environment started." 
}

main "$@"
