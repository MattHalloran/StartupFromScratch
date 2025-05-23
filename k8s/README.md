# Kubernetes Configuration for Vrooli

This directory (`k8s/`) contains the Kubernetes configurations required to deploy the Vrooli application. We primarily use [Helm](https://helm.sh/) to package and manage these configurations.

## What is Kubernetes?

Briefly, Kubernetes (often abbreviated as K8s) is an open-source system for automating deployment, scaling, and management of containerized applications. It groups containers that make up an application into logical units for easy management and discovery.

## What is Helm?

Helm is a package manager for Kubernetes. It helps you define, install, and upgrade even the most complex Kubernetes applications. Helm uses a packaging format called "charts."

A **Helm chart** is a collection of files that describe a related set of Kubernetes resources. It allows you to:
*   Define your application resources (Deployments, Services, ConfigMaps, Secrets, etc.) as templates.
*   Manage application configuration through values files.
*   Package and version your application for easy distribution and deployment.
*   Manage the lifecycle of your deployed applications (install, upgrade, rollback).

## Directory Structure Overview

Our Kubernetes configurations are primarily located within the `k8s/chart/` directory, which represents our Helm chart for the Vrooli application:

```
k8s/
├── chart/                # Helm chart for the Vrooli application
│   ├── Chart.yaml        # Metadata about the chart (name, version, dependencies)
│   ├── values.yaml       # Default configuration values for the chart
│   ├── values-dev.yaml   # Environment-specific values for 'development'
│   ├── values-prod.yaml  # Environment-specific values for 'production'
│   ├── templates/        # Directory of templates that generate Kubernetes manifests
│   │   ├── _helpers.tpl
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml
│   │   ├── pvc.yaml
│   │   ├── ingress.yaml
│   │   ├── NOTES.txt
│   │   └── tests/        # Directory for templated test files (e.g., ui-test.yaml)
│   ├── tests/            # Optional: Directory for other test files (e.g., scripts)
│   └── .helmignore       # Specifies files to ignore when packaging the chart
│
└── README.md             # This file (explaining the k8s directory structure)
```

## Vrooli Helm Chart Details (`k8s/chart/`)

This section provides specific details about the Vrooli Helm chart located in the `k8s/chart/` directory.

### Prerequisites

- Kubernetes 1.19+ cluster
- Helm 3.x installed
- Container images (`ui`, `server`, `jobs`, etc.) available in your configured container registry (see `image.registry` value in `k8s/chart/values.yaml`)

### Chart Structure (within `k8s/chart/`)

The primary components of the Helm chart in `k8s/chart/` are:
*   `Chart.yaml`: Contains metadata about the chart.
*   `values.yaml`: Provides default configuration values.
*   `values-dev.yaml`, `values-prod.yaml`: Offer environment-specific overrides for `values.yaml`.
*   `.helmignore`: Specifies patterns for files to exclude when packaging.
*   `templates/`: This directory contains the core Kubernetes manifest templates:
    *   `_helpers.tpl`: Common helper templates and partials.
    *   `deployment.yaml`: Template for Kubernetes Deployments.
    *   `service.yaml`: Template for Kubernetes Services.
    *   `configmap.yaml`: Template for ConfigMaps (non-sensitive configuration).
    *   `secret.yaml`: Template for Secrets (sensitive configuration).
    *   `pvc.yaml`: Template for PersistentVolumeClaims.
    *   `ingress.yaml`: Template for Ingress resources.
    *   `NOTES.txt`: Contains post-installation notes displayed to the user.
    *   `templates/tests/`: This subdirectory holds templated test files that Helm can run to verify a release (e.g., `ui-test.yaml`, `server-test.yaml`).
*   `tests/`: This optional top-level directory within the chart can contain other non-templated test files or scripts (e.g., `test-golden-files.sh`).


### Installing the Chart

1.  **Package the Chart (Optional, if not deploying from the directory directly):**
    ```bash
    helm package k8s/chart/
    ```
    This creates a versioned `.tgz` file of your chart.

2.  **Install or Upgrade a Release:**

    *   **Development/Staging Environment Example:**
        To install the chart with the release name `vrooli-dev` into a specific namespace (e.g., `staging`), using development values:
        ```bash
        helm install vrooli-dev k8s/chart/ \
          -f k8s/chart/values.yaml \
          -f k8s/chart/values-dev.yaml \
          --namespace staging --create-namespace
        ```
        This command installs the chart from the `k8s/chart/` directory, names the release `vrooli-dev`, uses overrides from `values-dev.yaml` (layered on top of `values.yaml`), and deploys it into the `staging` namespace (creating it if it doesn't exist).

    *   **Production Environment Example:**
        To install or upgrade the chart with the release name `vrooli-prod` into a specific namespace (e.g., `production`), using production-specific values:
        ```bash
        helm upgrade --install vrooli-prod k8s/chart/ \
          -f k8s/chart/values.yaml \
          -f k8s/chart/values-prod.yaml \
          --namespace production --create-namespace
        ```
        The `helm upgrade --install` command will install the chart if it's not already present, or upgrade it if it is.
        **Note:** Ensure you have thoroughly reviewed and customized `k8s/chart/values-prod.yaml` (especially image tags, hostnames, secrets, and resource allocations) before deploying to production.

### Uninstalling the Chart

To uninstall a release (e.g., `vrooli-dev` from the `staging` namespace):
```bash
helm uninstall vrooli-dev --namespace staging
helm uninstall vrooli-prod --namespace production
```

### Configuration Parameters

The following table lists some of the key configurable parameters of the Vrooli chart and their default values as typically defined in `k8s/chart/values.yaml`. Refer to the actual `values.yaml`, `values-dev.yaml`, and `values-prod.yaml` files in the `k8s/chart/` directory for the most up-to-date and complete list of configurations.

| Parameter                             | Description                                                                 | Default Value (from chart README)           |
| ------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------- |
| `nameOverride`                        | String to override the chart name component of resource names               | `""`                                        |
| `fullnameOverride`                    | String to fully override the `Release.Name-chartName` aresource names       | `""`                                        |
| `image.registry`                      | Global image registry prefix (e.g., `docker.io/myusername`)                 | `"your-registry/your-project"` (FIXME)      |
| `image.pullPolicy`                    | Global image pull policy for all services                                   | `IfNotPresent`                              |
| `replicaCount.ui`                     | Number of replicas for the UI service                                       | `1`                                         |
| `replicaCount.server`                 | Number of replicas for the Server service                                   | `1`                                         |
| `replicaCount.jobs`                   | Number of replicas for the Jobs service                                     | `1`                                         |
| `services.ui.repository`              | Image name (without registry) for UI service                              | `ui`                                        |
| `services.ui.tag`                     | Image tag for UI service                                                    | `dev`                                       |
| `services.ui.port`                    | Container port for UI service                                               | `3000`                                      |
| `services.ui.probes.livenessPath`     | Liveness probe HTTP path for UI service                                     | `/healthcheck`                              |
| `services.server.repository`          | Image name (without registry) for Server service                          | `server`                                    |
| `services.server.tag`                 | Image tag for Server service                                                | `dev`                                       |
| `services.server.port`                | Container port for Server service                                           | `5329`                                      |
| `services.jobs.repository`            | Image name (without registry) for Jobs service                            | `jobs`                                      |
| `services.jobs.tag`                   | Image tag for Jobs service                                                  | `dev`                                       |
| `config.env`                          | Environment setting (e.g., development, production)                       | `development`                               |
| `secrets`                             | Key-value pairs for Kubernetes Secrets (sensitive data). Empty by default.  | `{}`                                        |
| `persistence.postgres.enabled`        | Enable PersistentVolumeClaim for PostgreSQL                                 | `true`                                      |
| `persistence.postgres.size`           | Size for PostgreSQL PVC                                                     | `1Gi`                                       |
| `persistence.redis.enabled`           | Enable PersistentVolumeClaim for Redis                                      | `true`                                      |
| `persistence.redis.size`              | Size for Redis PVC                                                          | `512Mi`                                     |
| `ingress.enabled`                     | Enable Ingress resource                                                     | `false`                                     |
| `ingress.hosts`                       | Array of host rules for Ingress.                                            | `[]`                                        |

*(This is a subset of parameters. Refer to `k8s/chart/values.yaml` for all options.)*

### Important Operational Notes (from chart README)

*   **Container Registry & Image Tags:** The Docker image repositories and tags for your services (`server`, `jobs`, `ui`) are configured within the Helm chart's values files (e.g., `values.yaml`, `values-dev.yaml`). Ensure these point to your actual container registry and the correct image versions.
    *Example in `values.yaml` (structure may vary based on chart design):*
    ```yaml
    image:
      registry: your-registry/your-project # FIXME
      pullPolicy: IfNotPresent
    services:
      server:
        repository: server # Appends to image.registry if services.server.repositoryOverride is not set
        tag: latest
      ui:
        repository: ui
        tag: latest
    # ... and so on for other services
    ```
*   **Configuration Values:** Thoroughly review and customize `k8s/chart/values.yaml` and the environment-specific `values-*.yaml` files to match your application's requirements for each environment. This includes database connection strings, API keys, resource requests/limits, replica counts, etc.
*   **Secrets Management (Vault Integration):** This chart is designed to integrate with HashiCorp Vault via the Vault Secrets Operator (VSO) for managing sensitive data like API keys and database passwords.
    *   **Prerequisites:** A running HashiCorp Vault instance (can be in-cluster) and the Vault Secrets Operator must be installed and configured in your Kubernetes cluster.
    *   **Chart Configuration:**
        *   Enable VSO integration by setting `.Values.vso.enabled: true` in your values file.
        *   Configure `.Values.vso.vaultAddr` to point to your Vault service.
        *   Specify the Vault role VSO should use via `.Values.vso.k8sAuthRole`.
        *   Define which secrets to sync under `.Values.vso.secrets` by providing the Vault path and the desired Kubernetes Secret name (e.g., for PostgreSQL, Redis, general application secrets).
    *   **Workflow:** When deployed, this chart will create `VaultConnection`, `VaultAuth`, and `VaultSecret` custom resources. The VSO will use these to authenticate to Vault, fetch the specified secrets, and automatically create/update standard Kubernetes `Secret` objects in your release namespace.
    *   **Application Pods:** The application deployments (PostgreSQL, Redis, other services) are configured to mount these VSO-managed Kubernetes `Secret` objects to obtain their credentials and configuration.
    *   **Vault Population:** You are responsible for populating the actual secret data into the correct paths within your HashiCorp Vault instance.
    *   This approach centralizes secret management in Vault and aligns with best practices. Refer to the comments in `values.yaml` under the `vso` section and the VSO documentation for more details.
    *   The Kubernetes documentation on [Good practices for Kubernetes Secrets](https://kubernetes.io/docs/concepts/security/secrets-good-practices/) remains a valuable resource for understanding underlying concepts.
*   **Health Checks & Probes:** Ensure that the liveness and readiness probes defined in your Helm templates (e.g., in `templates/deployment.yaml`) correctly point to health check endpoints in your applications. The paths like `/healthcheck` are common defaults but might need adjustment.
*   **Resource Allocation:** The CPU and memory `requests` and `limits` defined in the chart's templates (and configurable via `values.yaml` or environment-specific values files) are crucial for stable operation. Monitor your application's performance and adjust these as needed for each environment.
*   **Stateful Services (PostgreSQL, Redis):**
    The chart includes PVC configuration for PostgreSQL and Redis in `values.yaml` (enabled by default in the original chart README). However, the base chart templates might not include `StatefulSet` definitions for these services. If you intend to deploy PostgreSQL or Redis as part of this Helm release (rather than using externally managed instances):
    1.  Ensure `StatefulSet` and `Service` manifest files exist in `k8s/chart/templates/` for each.
    2.  Configure their respective sections within `values.yaml` (e.g., under `.Values.services.postgres` or a dedicated `.Values.postgresql` section) so that the `StatefulSet` templates can access image, port, resources, and environment variable configurations.
    3.  Ensure the `replicaCount` for `postgres` and `redis` are set appropriately in your values files.
    Alternatively, if you are using external database services, ensure `persistence.postgres.enabled` and `persistence.redis.enabled` (or similar flags) are set to `false` in your values files to prevent unused PVC creation, and manage their connection strings via secrets.
*   **NSFW Detector GPU Usage (if applicable):**
    If the `nsfwDetector` service is part of your stack and can use GPUs:
    -   This requires your Kubernetes nodes to have GPUs and the appropriate device plugins (e.g., NVIDIA device plugin) installed and configured.
    -   Enable GPU usage by setting the relevant flags in your values file (e.g., `services.nsfwDetector.gpu.enabled: true`).
    -   Optionally, adjust GPU type (e.g., `services.nsfwDetector.gpu.type: "nvidia.com/gpu"`) and count.

This Helm chart provides a structured and maintainable way to manage your Kubernetes deployments as the Vrooli application evolves.

## Local Development Setup (Minikube + Local Chart)

This chart can be deployed to a local Minikube instance for development and testing.

**Prerequisites for Local Kubernetes Development:**

*   **Docker Desktop (or another container runtime like Podman):** Ensure it's running.
*   **Minikube:** For creating a local Kubernetes cluster.
*   **kubectl:** Kubernetes command-line tool.
*   **Helm:** The package manager for Kubernetes.

**Automated Setup using `scripts/main/setup.sh`:**

The recommended way to set up your local Kubernetes development environment (including Minikube, kubectl, Helm, an in-cluster Vault, and the Vault Secrets Operator) is by using the main project setup script with the `k8s-cluster` target:

```bash
bash scripts/main/setup.sh --target k8s-cluster --environment development --location local --secrets-source vault
```

*   `--target k8s-cluster`: Specifies that you want to set up for Kubernetes.
*   `--environment development`: Ensures development tools like Minikube are installed.
*   `--location local`: Standard for local setups.
*   `--secrets-source vault`: **Crucial!** This tells the script to:
    1.  Install HashiCorp Vault (via Helm chart) into your Minikube cluster (namespace: `vault`). It uses `k8s/dev-support/vault-values.yaml` which runs Vault in **dev mode** (single node, unsealed, in-memory, root token "root").
    2.  Configure the in-cluster Vault with Kubernetes authentication and a role (`vrooli-app`) for the Vault Secrets Operator.
    3.  Install the HashiCorp Vault Secrets Operator (VSO) (via Helm chart) into your Minikube cluster (namespace: `vault-secrets-operator-system`).

If Minikube is not already running, the script will attempt to start it.

**After Automated Setup:**

1.  **Vault is Ready:**
    *   Vault UI: Accessible via `kubectl port-forward svc/vault-ui -n vault 8200:8200` (then open `http://localhost:8200`, token: `root`).
    *   Vault CLI: `kubectl exec -n vault vault-0 -- env VAULT_TOKEN=root vault <command>`
2.  **VSO is Ready:** The Vault Secrets Operator is running and will look for `VaultAuth` and `VaultSecret` custom resources.
3.  **Populate Secrets in Vault:** You now need to populate the necessary secrets in your development Vault instance. The Helm chart (`values.yaml`) expects secrets at paths like:
    *   `secret/data/vrooli/redis` (e.g., key: `password`)
    *   `secret/data/vrooli/postgres` (e.g., keys: `username`, `password`)
    *   `secret/data/vrooli/app` (for general application secrets defined under `vso.secrets.app.mappings`)

    Example to put a Redis password:
    ```bash
    kubectl exec -n vault vault-0 -- env VAULT_TOKEN=root vault kv put secret/vrooli/redis password="yourSuperSecretDevRedisPassword"
    ```
    (Note: `secret/vrooli/redis` for KVv2 actually means the path in `vault kv put` is `secret/vrooli/redis` due to the `/data/` infix for KVv2 API paths, which is handled by the `vaultPath` in `values.yaml` like `secret/data/vrooli/redis`).

**Manual Installation/Verification of Tools (if not using the setup script):**

*   **kubectl:** [Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
*   **Helm:** [Install Helm](https://helm.sh/docs/intro/install/)
*   **Minikube:** [Install Minikube](https://minikube.sigs.k8s.io/docs/start/)
    *   Start Minikube: `minikube start --memory=4096 --cpus=2` (adjust resources as needed).
    *   Point Docker CLI to Minikube's Docker daemon (optional, for building images directly into Minikube): `eval $(minikube -p minikube docker-env)`

**Deploying the Vrooli Chart Locally:**

*   **Secrets Management (Vault Integration):** This chart is designed to integrate with HashiCorp Vault via the Vault Secrets Operator (VSO) for managing sensitive data.
    *   **Prerequisites for VSO:**
        *   A running HashiCorp Vault instance accessible from your Kubernetes cluster.
        *   The Vault Secrets Operator installed and configured in your Kubernetes cluster.
        *   The `k8s-cluster` setup target (as described above) will install a development Vault and VSO in Minikube if `SECRETS_SOURCE=vault` is specified.
    *   **Chart Configuration for VSO:**
        *   Enable VSO integration by setting `.Values.vso.enabled: true` in your `values.yaml` or a custom values file.
        *   Configure `.Values.vso.vaultAddr` to point to your Vault service (e.g., `http://vault.vault.svc:8200` for the dev setup).
        *   Example for Redis:
            ```yaml
            vso:
              enabled: true
              vaultAddr: "http://vault.vault.svc:8200" # For in-cluster Vault installed by setup script
              k8sAuthRole: "vrooli-app" # Role created by setup script
              secrets:
                redis:
                  enabled: true
                  vaultPath: "secret/data/vrooli/redis" # Path in Vault KVv2
                  k8sSecretName: "vrooli-redis-creds-from-vso" # Name of K8s secret VSO will create
                  # dataMappings allows you to map keys from Vault to keys in the K8s Secret
                  dataMappings:
                    - vaultKey: "password" # Key in Vault at the specified path
                      k8sKey: "REDIS_PASSWORD" # Key to be created in the Kubernetes Secret
                # ... other secret configurations for postgres, app ...
            ```
    *   The VSO will create Kubernetes `Secret` objects (e.g., `vrooli-redis-creds-from-vso`) based on the `VaultSecret` custom resources defined in `templates/vso-secrets.yaml`.
    *   Application deployments (`deployment.yaml`, `redis-statefulset.yaml`, `postgresql-statefulset.yaml`) are configured to mount these VSO-managed Kubernetes secrets.
*   **Production Secrets:**
    *   For production, Vault should be run in HA mode, properly secured, and backed up. The dev Vault installed by `setup.sh` is **NOT FOR PRODUCTION**.
    *   VSO would connect to your production-grade Vault instance.
    *   The `k8s-cluster` setup target (when `ENVIRONMENT=production`) primarily configures `kubectl` to connect to an existing cluster and does not install a new Vault instance.

## Configuration Parameters

The following table lists some of the key configurable parameters of the Vrooli chart and their default values as typically defined in `k8s/chart/values.yaml`. Refer to the actual `values.yaml`, `values-dev.yaml`, and `values-prod.yaml` files in the `k8s/chart/` directory for the most up-to-date and complete list of configurations.

| Parameter                             | Description                                                                 | Default Value (from chart README)           |
| ------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------- |
| `nameOverride`                        | String to override the chart name component of resource names               | `""`                                        |
| `fullnameOverride`                    | String to fully override the `Release.Name-chartName` aresource names       | `""`                                        |
| `image.registry`                      | Global image registry prefix (e.g., `docker.io/myusername`)                 | `"your-registry/your-project"` (FIXME)      |
| `image.pullPolicy`                    | Global image pull policy for all services                                   | `IfNotPresent`                              |
| `replicaCount.ui`                     | Number of replicas for the UI service                                       | `1`                                         |
| `replicaCount.server`                 | Number of replicas for the Server service                                   | `1`                                         |
| `replicaCount.jobs`                   | Number of replicas for the Jobs service                                     | `1`                                         |
| `services.ui.repository`              | Image name (without registry) for UI service                              | `ui`                                        |
| `services.ui.tag`                     | Image tag for UI service                                                    | `dev`                                       |
| `services.ui.port`                    | Container port for UI service                                               | `3000`                                      |
| `services.ui.probes.livenessPath`     | Liveness probe HTTP path for UI service                                     | `/healthcheck`                              |
| `services.server.repository`          | Image name (without registry) for Server service                          | `server`                                    |
| `services.server.tag`                 | Image tag for Server service                                                | `dev`                                       |
| `services.server.port`                | Container port for Server service                                           | `5329`                                      |
| `services.jobs.repository`            | Image name (without registry) for Jobs service                            | `jobs`                                      |
| `services.jobs.tag`                   | Image tag for Jobs service                                                  | `dev`                                       |
| `config.env`                          | Environment setting (e.g., development, production)                       | `development`                               |
| `secrets`                             | Key-value pairs for Kubernetes Secrets (sensitive data). Empty by default.  | `{}`                                        |
| `persistence.postgres.enabled`        | Enable PersistentVolumeClaim for PostgreSQL                                 | `true`                                      |
| `persistence.postgres.size`           | Size for PostgreSQL PVC                                                     | `1Gi`                                       |
| `persistence.redis.enabled`           | Enable PersistentVolumeClaim for Redis                                      | `true`                                      |
| `persistence.redis.size`              | Size for Redis PVC                                                          | `512Mi`                                     |
| `ingress.enabled`                     | Enable Ingress resource                                                     | `false`                                     |
| `ingress.hosts`                       | Array of host rules for Ingress.                                            | `[]`                                        |

*(This is a subset of parameters. Refer to `k8s/chart/values.yaml` for all options.)*

### Important Operational Notes (from chart README)

*   **Container Registry & Image Tags:** The Docker image repositories and tags for your services (`server`, `jobs`, `ui`) are configured within the Helm chart's values files (e.g., `values.yaml`, `values-dev.yaml`). Ensure these point to your actual container registry and the correct image versions.
    *Example in `values.yaml` (structure may vary based on chart design):*
    ```yaml
    image:
      registry: your-registry/your-project # FIXME
      pullPolicy: IfNotPresent
    services:
      server:
        repository: server # Appends to image.registry if services.server.repositoryOverride is not set
        tag: latest
      ui:
        repository: ui
        tag: latest
    # ... and so on for other services
    ```
*   **Configuration Values:** Thoroughly review and customize `k8s/chart/values.yaml` and the environment-specific `values-*.yaml` files to match your application's requirements for each environment. This includes database connection strings, API keys, resource requests/limits, replica counts, etc.
*   **Secrets Management (Vault Integration):** This chart is designed to integrate with HashiCorp Vault via the Vault Secrets Operator (VSO) for managing sensitive data like API keys and database passwords.
    *   **Prerequisites:** A running HashiCorp Vault instance (can be in-cluster) and the Vault Secrets Operator must be installed and configured in your Kubernetes cluster.
    *   **Chart Configuration:**
        *   Enable VSO integration by setting `.Values.vso.enabled: true` in your values file.
        *   Configure `.Values.vso.vaultAddr` to point to your Vault service.
        *   Specify the Vault role VSO should use via `.Values.vso.k8sAuthRole`.
        *   Define which secrets to sync under `.Values.vso.secrets` by providing the Vault path and the desired Kubernetes Secret name (e.g., for PostgreSQL, Redis, general application secrets).
    *   **Workflow:** When deployed, this chart will create `VaultConnection`, `VaultAuth`, and `VaultSecret` custom resources. The VSO will use these to authenticate to Vault, fetch the specified secrets, and automatically create/update standard Kubernetes `Secret` objects in your release namespace.
    *   **Application Pods:** The application deployments (PostgreSQL, Redis, other services) are configured to mount these VSO-managed Kubernetes `Secret` objects to obtain their credentials and configuration.
    *   **Vault Population:** You are responsible for populating the actual secret data into the correct paths within your HashiCorp Vault instance.
    *   This approach centralizes secret management in Vault and aligns with best practices. Refer to the comments in `values.yaml` under the `vso` section and the VSO documentation for more details.
    *   The Kubernetes documentation on [Good practices for Kubernetes Secrets](https://kubernetes.io/docs/concepts/security/secrets-good-practices/) remains a valuable resource for understanding underlying concepts.
*   **Health Checks & Probes:** Ensure that the liveness and readiness probes defined in your Helm templates (e.g., in `templates/deployment.yaml`) correctly point to health check endpoints in your applications. The paths like `/healthcheck` are common defaults but might need adjustment.
*   **Resource Allocation:** The CPU and memory `requests` and `limits` defined in the chart's templates (and configurable via `values.yaml` or environment-specific values files) are crucial for stable operation. Monitor your application's performance and adjust these as needed for each environment.
*   **Stateful Services (PostgreSQL, Redis):**
    The chart includes PVC configuration for PostgreSQL and Redis in `values.yaml` (enabled by default in the original chart README). However, the base chart templates might not include `StatefulSet` definitions for these services. If you intend to deploy PostgreSQL or Redis as part of this Helm release (rather than using externally managed instances):
    1.  Ensure `StatefulSet` and `Service` manifest files exist in `k8s/chart/templates/` for each.
    2.  Configure their respective sections within `values.yaml` (e.g., under `.Values.services.postgres` or a dedicated `.Values.postgresql` section) so that the `StatefulSet` templates can access image, port, resources, and environment variable configurations.
    3.  Ensure the `replicaCount` for `postgres` and `redis` are set appropriately in your values files.
    Alternatively, if you are using external database services, ensure `persistence.postgres.enabled` and `persistence.redis.enabled` (or similar flags) are set to `false` in your values files to prevent unused PVC creation, and manage their connection strings via secrets.
*   **NSFW Detector GPU Usage (if applicable):**
    If the `nsfwDetector` service is part of your stack and can use GPUs:
    -   This requires your Kubernetes nodes to have GPUs and the appropriate device plugins (e.g., NVIDIA device plugin) installed and configured.
    -   Enable GPU usage by setting the relevant flags in your values file (e.g., `services.nsfwDetector.gpu.enabled: true`).
    -   Optionally, adjust GPU type (e.g., `services.nsfwDetector.gpu.type: "nvidia.com/gpu"`) and count.

This Helm chart provides a structured and maintainable way to manage your Kubernetes deployments as the Vrooli application evolves. 