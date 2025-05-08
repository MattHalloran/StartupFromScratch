#!/usr/bin/env bash
set -euo pipefail
DESCRIPTION="Cleans up volumes, caches, packages, and other build artifacts. When complete, you should be able to set up the project from a clean slate."

SETUP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/flow.sh"
# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/locations.sh"
# shellcheck disable=SC1091
source "${SETUP_DIR}/../utils/logging.sh"

# Clear node_modules at the root and in all project subdirectories without descending into them
clear_node_modules() {
    header "Deleting all node_modules directories"
    # Prune node_modules directories to avoid find recursing into them after deletion
    find "${ROOT_DIR}" -maxdepth 4 -type d -name "node_modules" -prune -exec rm -rf {} +
}

# Clear apt cache and 
# WARNING: This is not recommended, and should only be used in an emergency.
clear_apt() {
    if ! can_run_sudo; then
        warn "Skipping apt cache cleaning due to lack of sudo access"
        return
    fi
    header "Cleaning apt cache and lists"

    # First, kill any hanging apt processes
    pkill -f apt

    # Clean up apt cache and lists
    apt-get clean
    find /var/lib/apt/lists/ -maxdepth 1 -type f -delete
    sudo rm -f /var/lib/dpkg/lock* /var/cache/apt/archives/lock
    
    success "Apt cache and lists cleaned."
}

# Prune docker system
prune_docker() {
    # Check if docker command exists
    if ! command -v docker &> /dev/null; then
        warn "Docker command not found, skipping Docker prune."
        return
    fi

    header "Pruning Docker system (images, containers, volumes, networks)"
    local force_flag=""
    if is_yes "$YES"; then
        force_flag="--force"
    fi
    local docker_command="docker system prune --all --volumes $force_flag"

    # Execute the command
    if $docker_command; then
        success "Docker system prune completed."
    else
        error "Docker system prune failed."
        # Optionally return an error code or let the script continue
    fi
}

# Peforms all cleanup steps
clean() {
    clear_node_modules
    # clear_apt
    prune_docker
}

