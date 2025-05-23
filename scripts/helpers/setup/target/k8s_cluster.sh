#!/usr/bin/env bash
# Posix-compliant script to setup the project for Kubernetes cluster development/production
set -euo pipefail

ORIGINAL_DIR=$(pwd)
SETUP_TARGET_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${SETUP_TARGET_DIR}/../../utils/env.sh"
# shellcheck disable=SC1091
source "${SETUP_TARGET_DIR}/../../utils/flow.sh"
# shellcheck disable=SC1091
source "${SETUP_TARGET_DIR}/../../utils/log.sh"
# shellcheck disable=SC1091
source "${SETUP_TARGET_DIR}/../../utils/system.sh"
# shellcheck disable=SC1091
source "${SETUP_TARGET_DIR}/../../utils/var.sh"

# Define installation directory and commands based on sudo availability
INSTALL_DIR="/usr/local/bin"
MV_CMD="sudo mv"
INSTALL_CMD="sudo install" # Using install for minikube
CHMOD_CMD="sudo chmod"
NEEDS_PATH_UPDATE="NO"

k8s_cluster::adjust_paths() {
    # Check if sudo is available and adjust paths/commands if not
    if ! flow::can_run_sudo; then
        log::warning "Sudo not available or skipped. Installing k8s tools to user directory."
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
            log::info "Added $INSTALL_DIR to PATH for current session."
            # Consider suggesting adding this to shell profile (e.g., ~/.bashrc)
        fi
    fi
}

# Install kubectl, which is used to manage the Kubernetes cluster
k8s_cluster::install_kubectl() {
    if ! system::is_command "kubectl"; then
        log::info "📦 Installing kubectl..."
        local arch
        case "$(uname -m)" in
            x86_64) arch="amd64" ;;
            aarch64|arm64) arch="arm64" ;;
            *) log::error "Unsupported architecture for kubectl: $(uname -m)" ;;
        esac

        local kubectl_url="https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/${arch}/kubectl"
        local tmp_kubectl
        tmp_kubectl=$(mktemp)

        if curl -Lo "$tmp_kubectl" "$kubectl_url"; then
            ${CHMOD_CMD} +x "$tmp_kubectl"
            ${MV_CMD} "$tmp_kubectl" "${INSTALL_DIR}/kubectl"
            log::success "kubectl installed successfully to ${INSTALL_DIR}"
        else
            log::error "Failed to download kubectl"
            rm -f "$tmp_kubectl"
            return 1 # Return error code
        fi
        rm -f "$tmp_kubectl" > /dev/null 2>&1

    else
        log::info "kubectl is already installed"
    fi
}

# Install Helm, which is used to manage Kubernetes charts
k8s_cluster::install_helm() {
    if ! system::is_command "helm"; then
        log::info "📦 Installing Helm..."
        # Use official Helm installation script to fetch and install the latest version
        # Adding retries for network reliability
        local attempt_num=1
        local max_attempts=3
        until curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; do
            if (( attempt_num == max_attempts )); then
                log::error "Failed to install Helm after $max_attempts attempts."
                return 1
            fi
            log::info "Helm installation attempt $attempt_num failed. Retrying in 5 seconds..."
            sleep 5
            attempt_num=$((attempt_num+1))
        done
        log::success "Helm installed successfully"
    else
        log::info "helm is already installed"
    fi
    # Ensure HashiCorp repo is added and updated
    if system::is_command "helm"; then
        log::info "Adding/Updating HashiCorp Helm repository..."
        helm repo add hashicorp https://helm.releases.hashicorp.com > /dev/null 2>&1 || log::warning "Failed to add HashiCorp repo (maybe already added)."
        helm repo update hashicorp || log::error "Failed to update HashiCorp Helm repository."
    fi
}

# Install Minikube, which is used to run a local Kubernetes cluster
k8s_cluster::install_minikube() {
    if ! system::is_command "minikube"; then
        log::info "📦 Installing minikube..."
        local arch
        case "$(uname -m)" in
            x86_64) arch="amd64" ;;
            aarch64|arm64) arch="arm64" ;;
            *) log::error "Unsupported architecture for minikube: $(uname -m)" ;;
        esac

        local minikube_url="https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${arch}"
        local tmp_minikube
        tmp_minikube=$(mktemp)

        if curl -Lo "$tmp_minikube" "$minikube_url"; then
            ${INSTALL_CMD} "$tmp_minikube" "${INSTALL_DIR}/minikube"
            rm -f "$tmp_minikube"
            log::success "Minikube installed successfully to ${INSTALL_DIR}"

            if system::is_command "kubectl"; then
                log::info "Renaming minikube context to vrooli-dev-cluster"
                kubectl config rename-context minikube vrooli-dev-cluster || log::warning "Failed to rename minikube context. It might not exist yet."
                log::info "Setting current context to vrooli-dev-cluster"
                kubectl config use-context vrooli-dev-cluster || log::warning "Failed to set current context to vrooli-dev-cluster."
            else
                log::warning "kubectl not found, skipping context configuration."
            fi
        else
            log::error "Failed to download Minikube"
            rm -f "$tmp_minikube"
            return 1 # Return error code
        fi

    else
        log::info "minikube is already installed"
    fi
}

# Install HashiCorp Vault using Helm for development
k8s_cluster::install_vault_helm_chart() {
    if ! helm status vault -n vault > /dev/null 2>&1; then
        log::info "📦 Installing HashiCorp Vault Helm chart for development..."
        # Ensure vault-values.yaml exists
        local vault_values_file="${var_ROOT_DIR}/k8s/dev-support/vault-values.yaml"
        if [ ! -f "$vault_values_file" ]; then
            log::error "Vault values file not found at $vault_values_file. Cannot install Vault."
            log::error "Please create it or check its path."
            # As a fallback, could attempt to create a minimal one or proceed without -f if chart has safe defaults for dev mode.
            # For now, erroring out.
            return 1
        fi

        if helm install vault hashicorp/vault \\
            --namespace vault \\
            --create-namespace \\
            -f "$vault_values_file" \\
            --wait --timeout 10m; then # Wait for resources to be ready
            log::success "HashiCorp Vault Helm chart installed successfully in 'vault' namespace."
            log::info "Vault UI might be accessible via LoadBalancer or 'kubectl port-forward svc/vault-ui -n vault 8200:8200'"
            log::info "Default dev root token is 'root'."
        else
            log::error "Failed to install HashiCorp Vault Helm chart."
            log::info "Check 'kubectl get pods -n vault' and 'kubectl logs -n vault -l app.kubernetes.io/name=vault' for errors."
            return 1
        fi
    else
        log::info "HashiCorp Vault seems to be already installed in 'vault' namespace (found with helm status)."
    fi
}

# Install HashiCorp Vault Secrets Operator (VSO) using Helm
k8s_cluster::install_vso_helm_chart() {
    if ! helm status vault-secrets-operator -n vault-secrets-operator-system > /dev/null 2>&1; then
        log::info "📦 Installing HashiCorp Vault Secrets Operator Helm chart..."
        if helm install vault-secrets-operator hashicorp/vault-secrets-operator \\
            --namespace vault-secrets-operator-system \\
            --create-namespace \\
            --wait --timeout 5m; then # Wait for VSO to be ready
            log::success "HashiCorp Vault Secrets Operator Helm chart installed successfully in 'vault-secrets-operator-system' namespace."
        else
            log::error "Failed to install HashiCorp Vault Secrets Operator Helm chart."
            log::info "Check 'kubectl get pods -n vault-secrets-operator-system' and logs for errors."
            return 1
        fi
    else
        log::info "HashiCorp Vault Secrets Operator seems to be already installed in 'vault-secrets-operator-system' namespace."
    fi
}

# Configure Vault for Kubernetes authentication (basic dev setup)
# Assumes Vault is running in dev mode with root token "root"
k8s_cluster::configure_dev_vault() {
    log::info "⚙️ Configuring development Vault instance..."

    # Wait for Vault pod to be running
    log::info "Waiting for Vault pod (vault-0) to be ready..."
    if ! kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=300s; then
        log::error "Vault pod vault-0 did not become ready in time."
        return 1
    fi
    log::info "Vault pod vault-0 is ready."

    local VAULT_POD="vault-0"
    local VAULT_NAMESPACE="vault"
    local VAULT_K8S_AUTH_ROLE_NAME="vrooli-app" # Must match values.vso.k8sAuthRole
    
    # For development, we'll allow the role to be used by 'default' service accounts
    # from any namespace where a Vrooli dev instance might be deployed.
    # For a tighter setup, specify exact namespaces.
    local BOUND_SA_NAMESPACES="*" 
    local BOUND_SA_NAMES="default" # Assumes VaultAuth in the app's namespace uses the 'default' SA

    log::info "Attempting to enable Kubernetes auth method in Vault..."
    # Check if already enabled
    if ! kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- vault auth list -format=json | jq -e '.["kubernetes/"]'; then
        if ! kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- vault auth enable kubernetes; then
            log::error "Failed to enable Kubernetes auth method in Vault."
            return 1
        fi
        log::success "Kubernetes auth method enabled in Vault."
    else
        log::info "Kubernetes auth method already enabled in Vault."
    fi

    log::info "Configuring Kubernetes auth method..."
    # Get Kubernetes service account issuer and host details (requires service account in Vault pod)
    # The official Vault Helm chart sets up necessary RBAC for this.
    # This assumes the default service account token for the Vault pod can access the tokenreview API and k8s API server.
    # Note: Using VAULT_SKIP_VERIFY=true for simplicity in dev. Production would need proper CA setup.
    # The command `kubectl exec ... -- vault write auth/kubernetes/config ...` needs the VAULT_TOKEN to be set.
    # Since we are using dev mode, the root token is 'root'.
    # We pass it directly to the vault command.
    # Fetch Kubernetes host and CA from within the cluster (from vault pod's perspective)
    local K8S_HOST
    K8S_HOST=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- printenv KUBERNETES_PORT_443_TCP_ADDR)
    if [ -z "$K8S_HOST" ]; then
        K8S_HOST=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- getent hosts kubernetes.default.svc | awk '{ print $1 }')
        if [ -z "$K8S_HOST" ]; then
            log::warning "Could not automatically determine Kubernetes host from Vault pod. Using default."
            K8S_HOST="kubernetes.default.svc" # This might not resolve if vault pod DNS is misconfigured.
        fi
    fi
    
    local K8S_PORT="443" # Default HTTPS port

    # Get the service account JWT and CA cert from the Vault pod's environment
    # The Vault Helm chart should mount these.
    # Path to the service account token Vault will use to validate other tokens
    local SA_JWT_TOKEN_PATH="/var/run/secrets/kubernetes.io/serviceaccount/token"
    # Path to the CA certificate for the K8s API server
    local SA_CA_CERT_PATH="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

    # Construct the command to write Kubernetes auth config
    # The token_reviewer_jwt needs to be read from the file inside the pod
    # The kubernetes_ca_cert also needs to be read from the file inside the pod
    # The `kubernetes_host` needs to be the internal cluster IP for the API server
    
    log::info "Writing Kubernetes auth config to Vault (Host: https://${K8S_HOST}:${K8S_PORT})..."
    # The values for token_reviewer_jwt and kubernetes_ca_cert are read *inside* the pod by Vault itself when it processes the API call.
    # We tell Vault *where* to find them.
    # However, for `vault write` CLI, we need to pass the *content* of the CA cert.
    # The `kubernetes_host` is critical.
    # Using default issuer.

    # Read the CA cert content to pass to vault write
    local K8S_CA_CERT_CONTENT
    K8S_CA_CERT_CONTENT=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- cat "$SA_CA_CERT_PATH")
    
    if ! kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- env VAULT_TOKEN=root vault write auth/kubernetes/config \
        token_reviewer_jwt=@"$SA_JWT_TOKEN_PATH" \
        kubernetes_host="https://${K8S_HOST}:${K8S_PORT}" \
        kubernetes_ca_cert="$K8S_CA_CERT_CONTENT" \
        issuer="https://kubernetes.default.svc.cluster.local"; then # Adjust issuer if necessary
        log::error "Failed to write Kubernetes auth config in Vault."
        log::info "You may need to manually configure it using 'kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault write auth/kubernetes/config ...'"
        return 1
    fi
    log::success "Kubernetes auth method configured in Vault."


    log::info "Creating Vault role '${VAULT_K8S_AUTH_ROLE_NAME}' for Vrooli application..."
    # This role allows pods with specific service accounts in specific namespaces to authenticate.
    # For VSO, the operator itself will authenticate using a role. For application pods to get secrets directly (if not using VSO), they'd need a role.
    # The role for VSO to use when syncing secrets should be configured in values.yaml (vso.k8sAuthRole).
    # Here we create that role.
    # bound_service_account_names should be the SA that VSO itself runs as (if VSO needs to auth to Vault directly for *itself*)
    # OR the SA that the application pods will run as (if they were to auth directly, which they won't with VSO).
    # For VSO, it needs a policy that allows it to read the configured secret paths.
    
    # Let's assume the VSO pod runs with a service account like 'vault-secrets-operator' in 'vault-secrets-operator-system'
    # Or if using a default SA for the vrooli app itself, it would be 'default' in APP_NAMESPACE
    # For the VSO CRDs (VaultAuth), the 'role' specified there is this Vault role.

    if ! kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- env VAULT_TOKEN=root vault write "auth/kubernetes/role/${VAULT_K8S_AUTH_ROLE_NAME}" \
        bound_service_account_names="${BOUND_SA_NAMES}" \\
        bound_service_account_namespaces="${BOUND_SA_NAMESPACES}" \\
        policies="default" \\ # CRITICAL: This needs to be a more restrictive policy for production.
        ttl="24h"; then
        log::error "Failed to create Vault role '${VAULT_K8S_AUTH_ROLE_NAME}'."
        log::info "You may need to manually create it."
        return 1
    fi
    log::success "Vault role '${VAULT_K8S_AUTH_ROLE_NAME}' created."
    
    # Optional: Create a default policy for vrooli-app if 'default' is not sufficient
    # Example:
    # kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- env VAULT_TOKEN=root vault policy write vrooli-app-policy - <<EOF
    # path "secret/data/vrooli/*" {
    #   capabilities = ["read"]
    # }
    # EOF
    # And then assign `policies="vrooli-app-policy"` to the role.

    # For KV v2, enable at secret/ if not already there (Helm chart usually does this)
    log::info "Ensuring KVv2 engine is mounted at 'secret/'..."
    if ! kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- env VAULT_TOKEN=root vault secrets list -format=json | jq -e '.["secret/"]'; then
        if ! kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- env VAULT_TOKEN=root vault secrets enable -path=secret kv-v2; then
            log::error "Failed to enable KVv2 secrets engine at 'secret/'."
            # return 1 # This might not be critical if it already exists but not listed as expected.
        else
            log::success "KVv2 secrets engine enabled at 'secret/'."
        fi
    else
        log::info "Secrets engine at 'secret/' seems to exist."
    fi


    log::success "Development Vault basic configuration complete."
    log::info "Next steps: Populate secrets in Vault at paths like 'secret/data/vrooli/redis', 'secret/data/vrooli/postgres', 'secret/data/vrooli/app'."
    log::info "Example: kubectl exec -n vault vault-0 -- env VAULT_TOKEN=root vault kv put secret/vrooli/redis password=yourredispassword"
}

k8s_cluster::install_kubernetes() {
    k8s_cluster::adjust_paths
    k8s_cluster::install_kubectl
    k8s_cluster::install_helm # Helm installation now also adds HashiCorp repo

    if env::in_development; then
        k8s_cluster::install_minikube
        # Attempt to start Minikube if not running
        if system::is_command "minikube" && ! minikube status > /dev/null 2>&1; then
            log::info "🚀 Starting Minikube..."
            # Add more memory and CPU if possible, adjust based on your system
            minikube start --memory=4096 --cpus=2 || log::error "Minikube failed to start."
        elif system::is_command "minikube"; then
            log::info "Minikube is already running."
        fi

        # Install Vault and VSO only if SECRETS_SOURCE is vault and in development
        # Convert SECRETS_SOURCE to lowercase for comparison
        local secrets_source_lower
        secrets_source_lower=$(echo "${SECRETS_SOURCE:-file}" | tr '[:upper:]' '[:lower:]')
        if [[ "$secrets_source_lower" == "v" || "$secrets_source_lower" == "vault" || "$secrets_source_lower" == "hashicorp" || "$secrets_source_lower" == "hashicorp-vault" ]]; then
            if k8s_cluster::install_vault_helm_chart; then
                # Only configure Vault if install was successful (or already installed and we assume it's usable)
                 k8s_cluster::configure_dev_vault || log::warning "Dev Vault configuration partly failed. Manual steps might be needed."
            else
                log::error "Skipping Vault configuration due to installation failure."
            fi
            k8s_cluster::install_vso_helm_chart || log::error "Vault Secrets Operator installation failed. VSO-based secrets won't work."
        else
            log::info "SECRETS_SOURCE is not 'vault'. Skipping in-cluster Vault and VSO installation."
        fi
    else
        log::info "📦 Configuring production Kubernetes cluster 'vrooli-prod-cluster'..."
        : "${KUBE_API_SERVER:?Environment variable KUBE_API_SERVER must be set}"
        : "${KUBE_CA_CERT_PATH:?Environment variable KUBE_CA_CERT_PATH must be set}"
        kubectl config set-cluster vrooli-prod-cluster \
            --server="${KUBE_API_SERVER}" \
            --certificate-authority="${KUBE_CA_CERT_PATH}" \
            --embed-certs=true
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
        kubectl config set-context vrooli-prod-cluster \
            --cluster=vrooli-prod-cluster \
            --user=prod-user
        kubectl config use-context vrooli-prod-cluster
        log::success "Production Kubernetes cluster 'vrooli-prod-cluster' configured successfully"
    fi
}

k8s_cluster::setup_k8s_cluster() {
    log::header "Setting up Kubernetes cluster development/production..."

    k8s_cluster::install_kubernetes
}

# If this script is run directly, invoke its main function.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    k8s_cluster::setup_k8s_cluster "$@"
fi 