#!/usr/bin/env bash
# Posix-compliant script to setup the project for Kubernetes cluster development/production
set -euo pipefail

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../../utils/index.sh"

# Install kubectl, which is used to manage the Kubernetes cluster
install_kubectl() {
    if ! [ -x "$(command -v kubectl)" ]; then
        info "📦 Installing kubectl..."

        # Install Kubernetes
        curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl

        if ! [ -x "$(command -v kubectl)" ]; then
            error "Failed to install Kubernetes"
            cd "$ORIGINAL_DIR"
            exit 1
        else
            success "Kubernetes installed successfully"
        fi
    else
        info "kubectl is already installed"
    fi
}

# Install Helm, which is used to manage Kubernetes charts
install_helm() {
    if ! [ -x "$(command -v helm)" ]; then
        info "📦 Installing Helm..."

        # Install Helm
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
        chmod 700 get_helm.sh
        trap 'rm -f get_helm.sh' EXIT
        ./get_helm.sh

        if ! [ -x "$(command -v helm)" ]; then
            error "Failed to install Helm"
            cd "$ORIGINAL_DIR"
            exit 1
        else
            success "Helm installed successfully"
        fi
    else
        info "helm is already installed"
    fi
}

# Install Minikube, which is used to run a local Kubernetes cluster
install_minikube() {
    if ! [ -x "$(command -v minikube)" ]; then
        info "📦 Installing minikube..."

        # Install Minikube
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube

        if ! [ -x "$(command -v minikube)" ]; then
            error "Failed to install Minikube"
            cd "$ORIGINAL_DIR"
            exit 1
        else
            success "Minikube installed successfully"
        fi

        # Rename Minikube context to dev-cluster
        kubectl config rename-context minikube vrooli-dev-cluster
        # Set dev-cluster as the current context
        kubectl config use-context vrooli-dev-cluster
    else
        info "minikube is already installed"
    fi
}

install_kubernetes() {
    install_kubectl
    install_helm

    if [ "${ENVIRONMENT}" = "development" ]; then
        install_minikube
    else
        info "📦 Configuring production Kubernetes cluster 'vrooli-prod-cluster'..."
        # Ensure required environment variables are set
        : "${KUBE_API_SERVER:?Environment variable KUBE_API_SERVER must be set}"
        : "${KUBE_CA_CERT_PATH:?Environment variable KUBE_CA_CERT_PATH must be set}"
        # Configure the cluster
        kubectl config set-cluster vrooli-prod-cluster \
            --server="${KUBE_API_SERVER}" \
            --certificate-authority="${KUBE_CA_CERT_PATH}" \
            --embed-certs=true
        # Configure credentials: use bearer token if provided, otherwise certificate-based auth
        if [ -n "${KUBE_BEARER_TOKEN:-}" ]; then
            kubectl config set-credentials prod-user --token="${KUBE_BEARER_TOKEN}"
        else
            : "${KUBE_CLIENT_CERT_PATH:?Environment variable KUBE_CLIENT_CERT_PATH must be set}"
            : "${KUBE_CLIENT_KEY_PATH:?Environment variable KUBE_CLIENT_KEY_PATH must be set}"
            kubectl config set-credentials prod-user \
                --client-certificate="${KUBE_CLIENT_CERT_PATH}" \
                --client-key="${KUBE_CLIENT_KEY_PATH}" \
                --embed-certs=true
        fi
        # Create and switch to the production context
        kubectl config set-context vrooli-prod-cluster \
            --cluster=vrooli-prod-cluster \
            --user=prod-user
        kubectl config use-context vrooli-prod-cluster
        success "Production Kubernetes cluster 'vrooli-prod-cluster' configured successfully"
    fi
}

setup_k8s_cluster() {
    header "Setting up Kubernetes cluster development/production..."

    install_kubernetes
}
