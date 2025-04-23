#!/bin/bash
# Posix-compliant script to make sure they keyless ssh login is enabled
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"

# enable PasswordAuthentication for ssh
enable_password_authentication() {
    header "Enabling PasswordAuthentication"
    sudo sed -i 's/#\?PasswordAuthentication .*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    sudo sed -i 's/#\?PubkeyAuthentication .*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
    sudo sed -i 's/#\?AuthorizedKeysFile .*/AuthorizedKeysFile .ssh\/authorized_keys/g' /etc/ssh/sshd_config
}

# Ensure .ssh directory and authorized_keys file exist with correct permissions
ensure_ssh_files() {
    mkdir -p ~/.ssh
    touch ~/.ssh/authorized_keys
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys
}

# Try restarting SSH service, checking for both common service names
restart_ssh() {
    if ! sudo systemctl restart sshd 2>/dev/null; then
        if ! sudo systemctl restart ssh 2>/dev/null; then
            echo "Failed to restart ssh. Exiting with error."
            exit 1
        fi
    fi
}

setup_ssh() {
    header "Setting up SSH"

    enable_password_authentication
    ensure_ssh_files
    restart_ssh
}

