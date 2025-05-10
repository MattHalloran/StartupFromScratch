#!/usr/bin/env bash
set -euo pipefail

UTILS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${UTILS_DIR}/flow.sh"
# shellcheck disable=SC1091
source "${UTILS_DIR}/log.sh"
# shellcheck disable=SC1091
source "${UTILS_DIR}/system.sh"

# Returns 0 if TCP port $1 has a listening process
ports::is_port_in_use() {
    local port=$1
    if ! system::is_command "lsof"; then
        log::error "lsof is required to check ports"
        return 1
    fi
    local pids
    pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN) || pids=""
    [[ -n "$pids" ]]
}

# Kills processes listening on TCP port $1
ports::kill() {
    local port=$1
    local pids
    pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN) || pids=""
    if [[ -n "$pids" ]]; then
        flow::maybe_run_sudo kill $pids
        log::success "Killed processes on port $port: $pids"
    fi
}

# If port is in use, prompt user to kill blockers
ports::check_and_free() {
    local port=$1
    local yes=${2:-$YES}
    if ports::is_port_in_use "$port"; then
        local pids
        pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN)
        log::warning "Port $port is in use by process(es): $pids"
        if flow::is_yes "$yes"; then
            ports::kill "$port"
        else
            if flow::confirm "Kill process(es) listening on port $port?"; then
                ports::kill "$port"
            else
                flow::exit_with_error "Please free port $port and retry" "$ERROR_USAGE"
            fi
        fi
    fi
} 