HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${HERE}/../utils/logging.sh"

# One-line confirmation prompt
prompt_confirm() {
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

# Only run a function if the script is executed (not sourced)
run_if_executed() {
    local callback="$1"
    shift # Remove the first argument
    if [[ "${BASH_SOURCE[1]}" == "${0}" ]]; then
        "$callback" "$@"
    fi
}

# ------------------------------------------------------------------
# Runs a command, prints an error, and exits if the command fails.
# Usage:
#   run_step "Friendly step description" "actual_command_here"
# ------------------------------------------------------------------
run_step() {
    local step_description="$1"
    shift
    local cmd="$*"

    info "${step_description}..."
    if ! eval "${cmd}"; then
        error "Failed: ${step_description}"
        exit 1
    fi
    success "${step_description} - done!"
}

# ------------------------------------------------------------------
# Runs a command, prints an error if it fails, but does NOT exit.
# Usage:
#   run_step_noncritical "Friendly step description" "actual_command_here"
# ------------------------------------------------------------------
run_step_noncritical() {
    local step_description="$1"
    shift
    local cmd="$*"

    info "${step_description}..."
    if ! eval "${cmd}"; then
        warning "Non-critical step failed: ${step_description}"
        # We do not exit here
        return 1
    fi
    success "${step_description} - done!"
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
