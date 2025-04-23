#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

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
