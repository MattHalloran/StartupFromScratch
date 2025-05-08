#!/usr/bin/env bash
set -euo pipefail
DESCRIPTION="Starts the development environment."

MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/arguments.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/flow.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/locations.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/logging.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/targetMatcher.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/develop/index.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/develop/target/index.sh"

parse_arguments() {
    arg_reset

    arg_register_help
    arg_register_sudo_mode
    arg_register_yes
    arg_register_location
    arg_register_environment
    arg_register_target
    arg_register_detached

    if is_asking_for_help "$@"; then
        arg_usage "$DESCRIPTION"
        print_exit_codes
        exit 0
    fi

    arg_parse "$@" >/dev/null

    export TARGET=$(arg_get "target")
    export SUDO_MODE=$(arg_get "sudo-mode")
    export YES=$(arg_get "yes")
    export LOCATION=$(arg_get "location")
    export ENVIRONMENT=$(arg_get "environment")
    export DETACHED=$(arg_get "detached")
}

main() {
    parse_arguments "$@"
    header "🏃 Starting development environment for $(match_target "$TARGET")"

    source "${MAIN_DIR}/setup.sh" "$@"

    if [[ "$LOCATION" == "remote" ]]; then
        setup_reverse_proxy
        if ! is_yes "$DETACHED"; then
            trap 'info "Tearing down Caddy reverse proxy..."; stop_reverse_proxy' EXIT INT TERM
        fi
    fi
    execute_for_target "$TARGET" "start_development_" || exit "${ERROR_USAGE}"

    success "✅ Development environment started." 
}

main "$@"
