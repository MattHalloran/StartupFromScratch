#!/bin/bash
# Posix-compliant script to setup the project for Kubernetes cluster development/production

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${HERE}/../../utils/index.sh"

setup_k8s_cluster() {
    header "Setting up Kubernetes cluster development/production..."
}
