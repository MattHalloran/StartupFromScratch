#!/usr/bin/env bash
# Posix-compliant script to fix system clock. 
# An accurate system clock is often needed for installing/updating packages, and can 
# occasionally be set incorrectly.
set -euo pipefail

SETUP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/flow.sh"
# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/log.sh"

# Fix the system clock
clock::fix() {
    local can_sudo
    # Check for sudo capability; warn if unavailable but continue
    if ! flow::can_run_sudo; then
        log::warning "Skipping system clock accuracy check due to insufficient permissions"
        can_sudo=0
    else
        can_sudo=1
    fi

    # Always print header
    log::header "Making sure the system clock is accurate"
    # Only run hwclock if sudo is available
    if [ "$can_sudo" -eq 1 ]; then
        sudo hwclock -s
    fi

    # Print info
    log::info "System clock is now: $(date)"
}