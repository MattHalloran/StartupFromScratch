#!/usr/bin/env bash
set -euo pipefail

SETUP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/logging.sh"
# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/system.sh"

setup_common_deps() {
    header "⚙️ Checking common dependencies (curl, jq)..."

    check_and_install "curl"
    check_and_install "jq"
    check_and_install "nproc"
    check_and_install "bc"
    check_and_install "free"
    check_and_install "awk"
    check_and_install "sed"
    check_and_install "grep"
    check_and_install "mkdir"
    check_and_install "systemctl"

    success "✅ Common dependencies checked/installed."
    return 0
} 