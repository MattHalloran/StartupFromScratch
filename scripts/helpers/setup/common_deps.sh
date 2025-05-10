#!/usr/bin/env bash
set -euo pipefail

SETUP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/log.sh"
# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/system.sh"

common_deps::check_and_install() {
    log::header "⚙️ Checking common dependencies (curl, jq)..."

    system::check_and_install "curl"
    system::check_and_install "jq"
    system::check_and_install "nproc"
    system::check_and_install "bc"
    system::check_and_install "free"
    system::check_and_install "awk"
    system::check_and_install "sed"
    system::check_and_install "grep"
    system::check_and_install "mkdir"
    system::check_and_install "systemctl"

    log::success "✅ Common dependencies checked/installed."
    return 0
} 