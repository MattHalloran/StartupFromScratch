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
clock::fix_system_clock() {
    if ! flow::can_run_sudo; then
        log::warning "Skipping system clock accuracy check due to insufficient permissions"
        return
    fi
    log::header "Making sure the system clock is accurate"
    sudo hwclock -s
    log::info "System clock is now: $(date)"
}