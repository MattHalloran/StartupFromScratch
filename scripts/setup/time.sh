#!/usr/bin/env bash
# Posix-compliant script to fix system clock. 
# An accurate system clock is often needed for installing/updating packages, and can 
# occasionally be set incorrectly.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/flow.sh"
# shellcheck disable=SC1091
source "${HERE}/../utils/logging.sh"

# Fix the system clock
fix_system_clock() {
    if ! can_run_sudo; then
        warning "Skipping system clock accuracy check due to insufficient permissions"
        return
    fi
    header "Making sure the system clock is accurate"
    sudo hwclock -s
    info "System clock is now: $(date)"
}