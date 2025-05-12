#!/bin/bash
# This script sets up keyless SSH access to a remote server.
# By default, tries to use SITE_IP from .env file, but can also be passed
# as a command line argument. Example usage:
#  ./scripts/keylessSsh.sh -i 123.456.789.012    # Connect to specific IP
#  ./scripts/keylessSsh.sh -s                 # Server setup mode
#  ./scripts/keylessSsh.sh -e /path/to/.env   # Use custom .env file

MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/locations.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/log.sh"

CONN_TIMEOUT_S=10
SETUP_MODE=false

# Read arguments
ENV_FILE="${ENV_PROD_FILE}"
while getopts "hsi:e:" opt; do
    case $opt in
    h)
        echo "Usage: $0 [-h] [-s] [-e ENV_FILE] [-i SITE_IP]"
        echo "  -h --help: Show this help message"
        echo "  -s --setup: Server setup mode, guides through new server creation"
        echo "  -e --env-file: .env file name (e.g. \".env\") (must be in root directory)"
        echo "  -i --ip: Optional IP address to connect to (overrides .env)"
        exit 0
        ;;
    s)
        SETUP_MODE=true
        ;;
    e)
        ENV_FILE=$OPTARG
        ;;
    i)
        SITE_IP=$OPTARG
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
done
shift $((OPTIND-1))

# Check for IP address as positional argument
if [ $# -ge 1 ]; then
    SITE_IP=$1
fi

# Server setup mode - generate key before server exists
if [ "$SETUP_MODE" = true ]; then
    log::info "Entering server setup mode..."
    log::info "We will guide you through creating a new VPS with preloaded SSH keys."
    log::info "Press any key to continue..."
    read -n 1 -s
    
    # Generate a temporary key pair
    temp_key_name="id_rsa_new_server"
    log::info "Generating SSH key pair for the new server..."
    ssh-keygen -t rsa -f ~/.ssh/${temp_key_name} -N ""
    
    # Display the public key for user to copy
    echo ""
    log::info "Copy the following public SSH key for your VPS setup form:"
    echo ""
    cat ~/.ssh/${temp_key_name}.pub
    echo ""
    
    log::info "After copying the key, press any key to continue..."
    read -n 1 -s
    
    log::info "Now setup your VPS with the copied SSH key."
    log::info "When the server is ready, enter the IP address:"
    read -p "Server IP: " SITE_IP
    
    if [ -z "$SITE_IP" ]; then
        log::error "No IP address provided. Exiting..."
        exit 1
    fi
    
    # Rename the key to match the server IP
    key_name="id_rsa_${SITE_IP}"
    log::info "Renaming key pair to match server IP (${key_name})..."
    mv ~/.ssh/${temp_key_name} ~/.ssh/${key_name}
    mv ~/.ssh/${temp_key_name}.pub ~/.ssh/${key_name}.pub
    
    # Ask if the user wants to update SITE_IP in ${ENV_FILE}
    log::info "Do you want to update SITE_IP in ${MAIN_DIR}/../${ENV_FILE}? (y/n)"
    read -n 1 -s update_env
    echo ""
    
    if [ "$update_env" = "y" ]; then
        if [ -f "${MAIN_DIR}/../${ENV_FILE}" ]; then
            # Check if SITE_IP exists in the file
            if grep -q "SITE_IP=" "${MAIN_DIR}/../${ENV_FILE}"; then
                # Update existing SITE_IP
                sed -i "s/SITE_IP=.*/SITE_IP=${SITE_IP}/" "${MAIN_DIR}/../${ENV_FILE}"
            else
                # Add SITE_IP to the file
                echo "SITE_IP=${SITE_IP}" >> "${MAIN_DIR}/../${ENV_FILE}"
            fi
            log::success "Updated SITE_IP in ${MAIN_DIR}/../${ENV_FILE}"
        else
            # Create new .env file
            echo "SITE_IP=${SITE_IP}" > "${MAIN_DIR}/../${ENV_FILE}"
            log::success "Created ${MAIN_DIR}/../${ENV_FILE} with SITE_IP=${SITE_IP}"
        fi
    fi
    
    # Continue with connection test
else
    # Load variables from .env file if SITE_IP not provided as argument
    if [ -z "${SITE_IP}" ]; then
        if [ -f "${MAIN_DIR}/../${ENV_FILE}" ]; then
            log::info "Loading variables from ${MAIN_DIR}/../${ENV_FILE}..."
            . "${MAIN_DIR}/../${ENV_FILE}"
        else
            log::error "Could not find ${ENV_FILE} file at ${MAIN_DIR}/../${ENV_FILE}. Exiting..."
            exit 1
        fi
        
        # Check if SITE_IP was loaded from ${ENV_FILE}
        if [ -z "${SITE_IP}" ]; then
            log::error "Could not find SITE_IP in ${ENV_FILE} file. Please provide IP as argument or in ${ENV_FILE}."
            exit 1
        fi
    else
        log::info "Using provided IP address: ${SITE_IP}"
    fi
    
    # Set the remote server location
    remote_server="root@${SITE_IP}"
    log::info "Remote server: ${remote_server}"

    # Remove local key pair if it was just generated within the last 5 minutes
    # This allows us to try again without having to manually delete the key pair,
    # while also keeping the key pair around if it was successful before
    remove_key_file() {
        key_name="id_rsa_${SITE_IP}"
        if [ -f ~/.ssh/${key_name} ] && [ $(find ~/.ssh/${key_name} -mmin -5 | wc -l) -gt 0 ]; then
            rm ~/.ssh/${key_name}*
        fi
    }

    # Check if there is already a public key for the project
    key_name="id_rsa_${SITE_IP}"
    if [ ! -f ~/.ssh/${key_name} ]; then
        # Generate a new SSH key pair for the project
        ssh-keygen -t rsa -f ~/.ssh/${key_name} -N ""
        # Copy the public key to the remote host
        cat ~/.ssh/${key_name}.pub | ssh ${remote_server} 'chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys; cat >> ~/.ssh/authorized_keys'
        if [ $? -ne 0 ]; then
            log::error "Failed to copy public key to remote host. Exiting..."
            rm ~/.ssh/${key_name}*
            exit 1
        fi
    fi
fi

# Common code for both modes: Test the SSH connection
remote_server="root@${SITE_IP}"
log::info "Testing SSH connection to ${remote_server}..."
ssh -i ~/.ssh/${key_name} -o "BatchMode=yes" -o "ConnectTimeout=${CONN_TIMEOUT_S}" ${remote_server} "echo 2>&1" >/dev/null
RET=$?
if [ ${RET} -ne 0 ]; then
    log::error "SSH connection failed: ${RET}. Retrying after removing old host key..."
    # Remove the known hosts entry for the remote server
    ssh-keygen -R ${SITE_IP}
    # Retry the SSH connection
    ssh -i ~/.ssh/${key_name} -o "BatchMode=yes" -o "ConnectTimeout=${CONN_TIMEOUT_S}" ${remote_server} "echo 2>&1" >/dev/null
    RET=$?
    if [ ${RET} -ne 0 ]; then
        log::error "SSH connection still failed: ${RET}. Exiting..."
        if [ "$SETUP_MODE" = false ]; then
            remove_key_file
        fi
        exit 1
    fi
fi
log::success "✅ SSH connection successful."
