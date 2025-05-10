#!/usr/bin/env bash
set -euo pipefail
DESCRIPTION="Starts the development environment."

MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/args.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/flow.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/locations.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/log.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/targetMatcher.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/develop/index.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/develop/target/index.sh"

parse_arguments() {
    args::reset

    args::register_help
    args::register_sudo_mode
    args::register_yes
    args::register_location
    args::register_environment
    args::register_target
    args::register_detached

    if args::is_asking_for_help "$@"; then
        args::usage "$DESCRIPTION"
        exit_codes::print
        exit 0
    fi

    args::parse "$@" >/dev/null

    export TARGET=$(args::get "target")
    export SUDO_MODE=$(args::get "sudo-mode")
    export YES=$(args::get "yes")
    export LOCATION=$(args::get "location")
    export ENVIRONMENT=$(args::get "environment")
    export DETACHED=$(args::get "detached")
}

main() {
    parse_arguments "$@"
    log::header "🏃 Starting development environment for $(match_target "$TARGET")"

    source "${MAIN_DIR}/setup.sh" "$@"

    if [[ "$LOCATION" == "remote" ]]; then
        setup_reverse_proxy
        if ! flow::is_yes "$DETACHED"; then
            trap 'info "Tearing down Caddy reverse proxy..."; stop_reverse_proxy' EXIT INT TERM
        fi
    fi
    execute_for_target "$TARGET" "start_development_" || exit "${ERROR_USAGE}"

    log::success "✅ Development environment started." 
}

main "$@"
