#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"

install_docker() {
    if ! can_run_sudo; then
        warning "Skipping Docker installation due to sudo mode"
        return
    fi

    if command -v docker &>/dev/null; then
        info "Detected: $(docker --version)"
        return 0
    fi

    info "Docker is not installed. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    trap 'rm -f get-docker.sh' EXIT
    sudo sh get-docker.sh
    # Check if Docker installation failed
    if ! command -v docker &>/dev/null; then
        echo "Error: Docker installation failed."
        return 1
    fi
}

start_docker() {
    if ! can_run_sudo; then
        warning "Skipping Docker start due to sudo mode"
        return
    fi

    # Try to start Docker (if already running, this should be a no-op)
    sudo service docker start

    # Verify Docker is running by attempting a command
    if ! docker version >/dev/null 2>&1; then
        error "Failed to start Docker or Docker is not running. If you are in Windows Subsystem for Linux (WSL), please start Docker Desktop and try again."
        return 1
    fi
}

restart_docker() {
    if ! can_run_sudo; then
        warning "Skipping Docker restart due to sudo mode"
        return
    fi

    info "Restarting Docker..."
    sudo service docker restart
}

setup_docker_compose() {
    if ! can_run_sudo; then
        warning "Skipping Docker Compose installation due to sudo mode"
        return
    fi

    if command -v docker-compose &>/dev/null; then
        info "Detected: $(docker-compose --version)"
        return 0
    fi

    info "Docker Compose is not installed. Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.15.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod a+rx /usr/local/bin/docker-compose
    # Check if Docker Compose installation failed
    if ! command -v docker-compose &>/dev/null; then
        echo "Error: Docker Compose installation failed."
        return 1
    fi
}

check_docker_internet() {
    header "Checking Docker internet access..."
    if docker run --rm busybox ping -c 1 google.com &>/dev/null; then
        success "Docker internet access: OK"
    else
        error "Docker internet access: FAILED"
        return 1
    fi
}

show_docker_daemon() {
    if [ -f /etc/docker/daemon.json ]; then
        info "Current /etc/docker/daemon.json:"
        cat /etc/docker/daemon.json
    else
        warning "/etc/docker/daemon.json does not exist."
    fi
}

update_docker_daemon() {
    if ! can_run_sudo; then
        warning "Skipping Docker daemon update due to sudo mode"
        return
    fi

    info "Updating /etc/docker/daemon.json to use Google DNS (8.8.8.8)..."

    # Check if /etc/docker/daemon.json exists
    if [ -f /etc/docker/daemon.json ]; then
        # Backup existing file
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
        info "Backup created at /etc/docker/daemon.json.backup"
    fi

    # Write new config
    sudo bash -c 'cat > /etc/docker/daemon.json' <<EOF
{
  "dns": ["8.8.8.8"]
}
EOF

    info "/etc/docker/daemon.json updated."
}

setup_docker_internet() {
    if ! check_docker_internet; then
        error "Docker cannot access the internet. This may be a DNS issue."
        show_docker_daemon

        if [ "$SKIP_CONFIRMATIONS" = "true" ]; then
            update_docker_daemon
            restart_docker
            info "Docker DNS updated. Retesting Docker internet access..."
            check_docker_internet && success "Docker internet access is now working!" || error "Docker internet access still failing."
        else
            prompt "Would you like to update /etc/docker/daemon.json to use Google DNS (8.8.8.8)? (y/n): " choice
            read -n1 -r choice
            echo
            if is_yes "$choice"; then
                update_docker_daemon
                restart_docker
                info "Docker DNS updated. Retesting Docker internet access..."
                check_docker_internet && success "Docker internet access is now working!" || error "Docker internet access still failing."
            else
                echo "No changes made."
            fi
        fi
    else
        echo "Docker already has internet access."
    fi
}

# Calculates resource limit values
calculate_docker_resource_limits() {
    # Get total number of CPU cores and calculate CPU quota.
    N=$(nproc)
    # Calculate quota: (N - 0.5) * 100. This value is later appended with '%' .
    QUOTA=$(echo "($N - 0.5) * 100" | bc)
    CPU_QUOTA="${QUOTA}%" 

    # Get total memory (in MB) and calculate 80% of it.
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    MEM_LIMIT=$(echo "$TOTAL_MEM * 0.8" | bc | cut -d. -f1)M
}

# Defines file paths for configuration
define_docker_config_files() {
    # This slice unit will hold the Docker daemon’s resource limits.
    SLICE_FILE="/etc/systemd/system/docker.slice"

    # The service override drop-in file ensures docker.service is placed in the Docker slice.
    SERVICE_OVERRIDE_DIR="/etc/systemd/system/docker.service.d"
    SERVICE_OVERRIDE_FILE="${SERVICE_OVERRIDE_DIR}/slice.conf"
}

# Update/create the slice unit file
update_docker_slice_file() {
    # We want the slice file to contain a [Slice] section with CPUQuota and MemoryMax.
    if [[ ! -f "$SLICE_FILE" ]]; then
        cat <<EOF > "$SLICE_FILE"
[Slice]
CPUQuota=${CPU_QUOTA}
MemoryMax=${MEM_LIMIT}
EOF
        changed=true
    else
        # Ensure the [Slice] header exists.
        if ! grep -q "^\[Slice\]" "$SLICE_FILE"; then
            sed -i "1i[Slice]" "$SLICE_FILE"
            changed=true
        fi
        # Update or add CPUQuota setting.
        if grep -q '^CPUQuota=' "$SLICE_FILE"; then
            old_cpu=$(grep '^CPUQuota=' "$SLICE_FILE" | head -n 1 | cut -d= -f2-)
            if [[ "$old_cpu" != "$CPU_QUOTA" ]]; then
                sed -i "s/^CPUQuota=.*/CPUQuota=${CPU_QUOTA}/" "$SLICE_FILE"
                changed=true
            fi
        else
            sed -i "/^\[Slice\]/a CPUQuota=${CPU_QUOTA}" "$SLICE_FILE"
            changed=true
        fi

        # Update or add MemoryMax setting.
        if grep -q '^MemoryMax=' "$SLICE_FILE"; then
            old_mem=$(grep '^MemoryMax=' "$SLICE_FILE" | head -n 1 | cut -d= -f2-)
            if [[ "$old_mem" != "$MEM_LIMIT" ]]; then
                sed -i "s/^MemoryMax=.*/MemoryMax=${MEM_LIMIT}/" "$SLICE_FILE"
                changed=true
            fi
        else
            sed -i "/^\[Slice\]/a MemoryMax=${MEM_LIMIT}" "$SLICE_FILE"
            changed=true
        fi
    fi
}

# Update/create the docker.service drop-in file
update_docker_service_override_file() {
    # Make sure the directory exists.
    mkdir -p "$SERVICE_OVERRIDE_DIR"

    # The override file should assign docker.service to the docker.slice.
    if [[ ! -f "$SERVICE_OVERRIDE_FILE" ]]; then
        cat <<EOF > "$SERVICE_OVERRIDE_FILE"
[Service]
Slice=docker.slice
EOF
        changed=true
    else
        # Ensure the [Service] header exists.
        if ! grep -q "^\[Service\]" "$SERVICE_OVERRIDE_FILE"; then
        sed -i "1i[Service]" "$SERVICE_OVERRIDE_FILE"
        changed=true
        fi

        # Check and update the Slice directive.
        if grep -q '^Slice=' "$SERVICE_OVERRIDE_FILE"; then
            old_slice=$(grep '^Slice=' "$SERVICE_OVERRIDE_FILE" | head -n 1 | cut -d= -f2-)
            if [[ "$old_slice" != "docker.slice" ]]; then
                sed -i "s/^Slice=.*/Slice=docker.slice/" "$SERVICE_OVERRIDE_FILE"
                changed=true
            fi
        else
            sed -i "/^\[Service\]/a Slice=docker.slice" "$SERVICE_OVERRIDE_FILE"
            changed=true
        fi
    fi
}

# Sets up a dedicated systemd slice for the Docker daemon
# and assigns the docker.service to this slice. It calculates resource
# limits based on system characteristics:
#  - CPUQuota: (total cores - 0.5)*100 (%)
#  - MemoryMax: 80% of the total memory (in MB)
#
# The Docker slice will be defined in /etc/systemd/system/docker.slice,
# and the docker.service override will be in
# /etc/systemd/system/docker.service.d/slice.conf.
setup_docker_resource_limits() {
    if ! can_run_sudo; then
        warning "Skipping Docker resource limits setup due to sudo mode"
        return
    fi

    header "Setting up Docker resource limits"

    changed=false
    calculate_docker_resource_limits
    define_docker_config_files
    update_docker_slice_file
    update_docker_service_override_file

    # Reload systemd if changes were made
    if [ "$changed" = true ]; then
        info "Docker slice configuration updated."
        systemctl daemon-reload
        systemctl restart docker.service
        success "Docker resource limits set up successfully."
    else
        success "Docker slice configuration unchanged. No action taken."
    fi
}

setup_docker() {
    install_docker
    start_docker
    setup_docker_compose
    setup_docker_internet
    setup_docker_resource_limits
}
