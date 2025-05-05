#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "${HERE}/logging.sh"
# shellcheck disable=SC1091
source "${HERE}/flow.sh"
# shellcheck disable=SC1091
source "${HERE}/system.sh"

# ------------------------------------------------------------------------------
# is_port_in_use: returns 0 if TCP port $1 has a listening process
# ------------------------------------------------------------------------------
is_port_in_use() {
    local port=$1
    if ! command -v lsof >/dev/null 2>&1; then
        error "lsof is required to check ports"
        return 1
    fi
    local pids
    pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN) || pids=""
    [[ -n "$pids" ]]
}

# ------------------------------------------------------------------------------
# kill_port: kills processes listening on TCP port $1
# ------------------------------------------------------------------------------
kill_port() {
    local port=$1
    local pids
    pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN) || pids=""
    if [[ -n "$pids" ]]; then
        maybe_run_sudo kill $pids
        success "Killed processes on port $port: $pids"
    fi
}

# ------------------------------------------------------------------------------
# check_and_free_port: if port is in use, prompt user to kill blockers
# ------------------------------------------------------------------------------
check_and_free_port() {
    local port=$1
    local yes=${2:-$YES}
    if is_port_in_use "$port"; then
        local pids
        pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN)
        warning "Port $port is in use by process(es): $pids"
        if is_yes "$yes"; then
            kill_port "$port"
        else
            if confirm "Kill process(es) listening on port $port?"; then
                kill_port "$port"
            else
                exit_with_error "Please free port $port and retry" "$ERROR_USAGE"
            fi
        fi
    fi
} 