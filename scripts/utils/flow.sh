#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/logging.sh"

# One-line confirmation prompt
confirm() {
    # If auto-confirm is enabled, skip the prompt
    if is_yes "$YES"; then
        info "Auto-confirm enabled, skipping prompt"
        return 0
    fi
    local message="$1"
    prompt "$message (y/n) "
    read -r -n 1 confirm
    echo
    case "$confirm" in
    [Yy]*) return 0 ;; # User confirmed
    *) return 1 ;;     # User did not confirm
    esac
}

# Exit with error message and code
exit_with_error() {
    local message="$1"
    local code="${2:-1}" # Default to exit code 1 if not provided
    error "$message"
    exit "$code"
}

# Continue with error message and code
continue_with_error() {
    local message="$1"
    local code="${2:-1}" # Default to exit code 1 if not provided
    error "$message"
    return "$code"
}

# ------------------------------------------------------------------------------
# is_yes: Returns 0 if the first argument is a recognized "yes" (y/yes), else 1.
# Usage:
#     if is_yes "$SOME_VAR"; then
#         echo "It's a yes!"
#     else
#         echo "It's a no!"
#     fi
# ------------------------------------------------------------------------------
is_yes() {
    # Convert to lowercase. Note that [A-Z] and [a-z] in `tr` are POSIX,
    # but using '[:upper:]' and '[:lower:]' is typically safer for all locales.
    ans=$(echo "$1" | tr '[:upper:]' '[:lower:]')

    case "$ans" in
    y | yes)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

# ------------------------------------------------------------------------------
# can_run_sudo: Checks if sudo can be invoked according to SUDO_MODE.
# Returns 0 if sudo operations should proceed, 1 if they should be skipped.
# Exits with error if SUDO_MODE is 'error' and sudo is unavailable.
# ------------------------------------------------------------------------------
can_run_sudo() {
    # Determine behavior based on SUDO_MODE
    local mode=${SUDO_MODE:-skip}

    # skip mode always returns non-zero (no sudo)
    if [[ "$mode" == "skip" ]]; then
        info "SUDO_MODE=skip: skipping privileged operations"
        return 1
    fi

    # If sudo is not installed, skip privileged ops
    if ! command -v sudo >/dev/null 2>&1; then
        info "sudo not found: skipping privileged operations"
        return 1
    fi

    # Test for passwordless sudo, but don't let 'set -e' kill us
    set +e
    sudo -n true >/dev/null 2>&1
    local status=$?
    set -e

    if [[ $status -eq 0 ]]; then
        return 0
    fi

    # If error mode, abort; otherwise just skip
    if [[ "$mode" == "error" ]]; then
        exit_with_error "Privileged operations require sudo access, but unable to run sudo" "$ERROR_DEFAULT"
    else
        info "sudo requires password or is blocked, skipping privileged operations"
        return 1
    fi
}

maybe_run_sudo() {
    if can_run_sudo; then
        sudo "$@"
    else
        "$@"
    fi
}