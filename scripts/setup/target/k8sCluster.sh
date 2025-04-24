#!/usr/bin/env bash
# Posix-compliant script to setup the project for Kubernetes cluster development/production
set -euo pipefail

ORIGINAL_DIR=$(pwd)
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../../utils/index.sh"

# Define installation directory and commands based on sudo availability
INSTALL_DIR="/usr/local/bin"
MV_CMD="sudo mv"
INSTALL_CMD="sudo install" # Using install for minikube
CHMOD_CMD="sudo chmod"
NEEDS_PATH_UPDATE="NO"

# Check if sudo is available and adjust paths/commands if not
if ! can_run_sudo; then
    warning "Sudo not available or skipped. Installing k8s tools to user directory."
    INSTALL_DIR="$HOME/.local/bin"
    MV_CMD="mv"
    INSTALL_CMD="install" # 'install' might work without sudo if target is writable
    CHMOD_CMD="chmod"
    NEEDS_PATH_UPDATE="YES"

    # Ensure the local bin directory exists
    mkdir -p "$INSTALL_DIR"

    # Ensure the local bin directory is in PATH for the current session
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        export PATH="$INSTALL_DIR:$PATH"
        info "Added $INSTALL_DIR to PATH for current session."
        # Consider suggesting adding this to shell profile (e.g., ~/.bashrc)
    fi
fi

# Install kubectl, which is used to manage the Kubernetes cluster
install_kubectl() {
    if ! command -v kubectl >/dev/null 2>&1; then
        info "📦 Installing kubectl..."
        local arch
        case "$(uname -m)" in
            x86_64) arch="amd64" ;;
            aarch64|arm64) arch="arm64" ;;
            *) error "Unsupported architecture for kubectl: $(uname -m)" ;;
        esac

        local kubectl_url="https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/${arch}/kubectl"
        local tmp_kubectl
        tmp_kubectl=$(mktemp)

        if curl -Lo "$tmp_kubectl" "$kubectl_url"; then
            ${CHMOD_CMD} +x "$tmp_kubectl"
            ${MV_CMD} "$tmp_kubectl" "${INSTALL_DIR}/kubectl"
            success "kubectl installed successfully to ${INSTALL_DIR}"
            # No need to check command -v again here, assume success if mv worked
        else
            error "Failed to download kubectl"
            rm -f "$tmp_kubectl" # Clean up temp file on failure
            # Exiting might be too harsh, consider returning error code
            # cd "$ORIGINAL_DIR" # No need to cd back if not exiting
            # exit 1
            return 1 # Return error code
        fi
        # Ensure temp file is removed even if mv fails but curl succeeded
        # However, MV_CMD might already handle this depending on implementation
        # Being safe:
        rm -f "$tmp_kubectl" > /dev/null 2>&1

    else
        info "kubectl is already installed"
    fi
}

# Install Helm, which is used to manage Kubernetes charts
install_helm() {
    if ! command -v helm > /dev/null 2>&1; then
        info "📦 Installing Helm..."
        local arch
        case "$(uname -m)" in
            x86_64) arch="amd64" ;;
            aarch64|arm64) arch="arm64" ;;
            *) error "Unsupported architecture for Helm: $(uname -m)" ;;
        esac

        local helm_version="latest" # Or pin to a specific version
        local helm_url="https://get.helm.sh/helm-v${helm_version}-linux-${arch}.tar.gz"
        local tmpdir
        tmpdir=$(mktemp -d)

        if curl -fsSL "$helm_url" | tar -xz -C "$tmpdir" --strip-components=1 "linux-${arch}/helm"; then
            # Move and make executable using determined command and path
            ${MV_CMD} "$tmpdir/helm" "${INSTALL_DIR}/helm"
            # Helm binary might already be executable, but ensure it
            ${CHMOD_CMD} +x "${INSTALL_DIR}/helm"
            rm -rf "$tmpdir"
            success "Helm installed successfully to ${INSTALL_DIR}"
        else
            warning "Download or extraction of Helm failed"
            rm -rf "$tmpdir"
            return 1 # Return error code
        fi
    else
        info "helm is already installed"
    fi
}

# Install Minikube, which is used to run a local Kubernetes cluster
install_minikube() {
    if ! command -v minikube >/dev/null 2>&1; then
        info "📦 Installing minikube..."
        local arch
        case "$(uname -m)" in
            x86_64) arch="amd64" ;;
            aarch64|arm64) arch="arm64" ;;
            *) error "Unsupported architecture for minikube: $(uname -m)" ;;
        esac

        local minikube_url="https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${arch}"
        local tmp_minikube
        tmp_minikube=$(mktemp)

        if curl -Lo "$tmp_minikube" "$minikube_url"; then
             # Use INSTALL_CMD which is 'sudo install' or 'install'
            ${INSTALL_CMD} "$tmp_minikube" "${INSTALL_DIR}/minikube"
            # 'install' command usually sets executable permissions, but ensure with CHMOD_CMD if needed
            # ${CHMOD_CMD} +x "${INSTALL_DIR}/minikube"
            rm -f "$tmp_minikube" # Clean up temp file
            success "Minikube installed successfully to ${INSTALL_DIR}"

            # Check if kubectl config commands need sudo? Unlikely, but worth noting.
            # Rename Minikube context to dev-cluster
            if command -v kubectl >/dev/null 2>&1; then
                 info "Renaming minikube context to vrooli-dev-cluster"
                 kubectl config rename-context minikube vrooli-dev-cluster || warning "Failed to rename minikube context. It might not exist yet."
                 # Set dev-cluster as the current context
                 info "Setting current context to vrooli-dev-cluster"
                 kubectl config use-context vrooli-dev-cluster || warning "Failed to set current context to vrooli-dev-cluster."
            else
                warning "kubectl not found, skipping context configuration."
            fi
        else
            error "Failed to download Minikube"
            rm -f "$tmp_minikube" # Clean up temp file on failure
            return 1 # Return error code
        fi

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
