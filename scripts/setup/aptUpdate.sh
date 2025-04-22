#!/bin/bash
# Posix-compliant script to update apt-get

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${HERE}/../utils/index.sh"


# Limits the number of apt-get update calls
should_run_apt_get_update() {
    local last_update=$(stat -c %Y /var/lib/apt/lists/)
    local current_time=$(date +%s)
    local update_interval=$((24 * 60 * 60)) # 24 hours

    if ((current_time - last_update > update_interval)); then
        return 0 # true, should run
    else
        return 1 # false, should not run
    fi
}

# Limit the number of apt-get upgrade calls
should_run_apt_get_upgrade() {
    local last_upgrade=$(stat -c %Y /var/lib/dpkg/status)
    local current_time=$(date +%s)
    local upgrade_interval=$((7 * 24 * 60 * 60)) # 1 week

    if ((current_time - last_upgrade > upgrade_interval)); then
        return 0 # true, should run
    else
        return 1 # false, should not run
    fi
}

run_apt_get_update_and_upgrade() {
    if should_run_apt_get_update; then
        header "Updating apt-get package lists"
        sudo apt-get update
    else
        info "Skipping apt-get update - last update was less than 24 hours ago"
    fi
    if should_run_apt_get_upgrade; then
        header "Upgrading apt-get packages"
        RUNLEVEL=1 sudo apt-get -y upgrade
    else
        info "Skipping apt-get upgrade - last upgrade was less than 1 week ago"
    fi
}