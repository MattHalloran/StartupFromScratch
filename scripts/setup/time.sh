#!/usr/bin/env bash
# Posix-compliant script to fix system clock. 
# An accurate system clock is often needed for installing/updating packages, and can 
# occasionally be set incorrectly.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"

# Fix the system clock
fix_system_clock() {
    header "Making sure the system clock is accurate"
    sudo hwclock -s
    info "System clock is now: $(date)"
}