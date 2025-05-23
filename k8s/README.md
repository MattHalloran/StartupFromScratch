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
*   Manage the lifecycle of your deployed applications (install, upgrade, rollback, test).

## Directory Structure Overview

Our Kubernetes configurations are primarily located within the `k8s/chart/` directory, which represents our Helm chart for the Vrooli application:

```
k8s/
├── chart/                # Helm chart for the Vrooli application
│   ├── Chart.yaml        # Metadata about the chart (name, version, dependencies)
│   ├── values.yaml       # Default configuration values for the chart
│   ├── values-dev.yaml   # Environment-specific values for 'development'
│   ├── values-prod.yaml  # Environment-specific values for 'production'
│   ├── .helmignore       # Specifies files to ignore when packaging the chart
│   ├── templates/        # Directory of templates that generate Kubernetes manifests
│   │   ├── _helpers.tpl  # Common helper functions and partials
│   │   ├── deployment.yaml # For ui, server, jobs, nsfwDetector
│   │   ├── service.yaml    # For ui, server, jobs, nsfwDetector services
│   │   ├── configmap.yaml  # For general application configuration
│   │   ├── pvc.yaml        # For PersistentVolumeClaims (e.g., for databases)
│   │   ├── ingress.yaml    # For exposing services externally
│   │   ├── postgresql-statefulset.yaml # StatefulSet for PostgreSQL
│   │   ├── postgresql-service.yaml     # Service for PostgreSQL
│   │   ├── redis-statefulset.yaml      # StatefulSet for Redis
│   │   ├── redis-service.yaml          # Service for Redis
│   │   ├── vso-auth.yaml         # VaultAuth CR for Vault Secrets Operator
│   │   ├── vso-connection.yaml   # VaultConnection CR for VSO
│   │   ├── vso-secrets.yaml      # VaultSecret CRs for VSO (syncs Vault secrets to K8s)
│   │   ├── NOTES.txt       # Post-installation notes
│   │   └── tests/          # Directory for templated test files
│   │       ├── configmap-value-test.yaml
│   │       ├── nsfwDetector-test.yaml
│   │       ├── jobs-test.yaml
│   │       ├── server-test.yaml
│   │       └── ui-test.yaml
│   ├── tests/            # Chart-level tests (non-templated)
│   │   └── test-golden-files.sh # Script for golden file testing
│
└── README.md             # This file (explaining the k8s directory structure and usage)
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
    *   `_helpers.tpl`: Common helper templates and partials used across other template files.
    *   `deployment.yaml`: Generates Kubernetes Deployments for services like `ui`, `server`, `jobs`, and `nsfwDetector` based on configurations in `values.yaml`.
    *   `service.yaml`: Generates Kubernetes Services to expose the deployments internally within the cluster.
    *   `configmap.yaml`: Creates a ConfigMap for non-sensitive application configuration.
    *   `postgresql-statefulset.yaml` & `redis-statefulset.yaml`: Define Kubernetes StatefulSets for deploying PostgreSQL and Redis, ensuring stable network identifiers and persistent storage.
    *   `postgresql-service.yaml` & `redis-service.yaml`: Define Kubernetes Services to expose PostgreSQL and Redis within the cluster.
    *   `pvc.yaml`: Generates PersistentVolumeClaims for services requiring persistent storage, primarily used by the StatefulSets.
    *   `ingress.yaml`: Defines Ingress rules for managing external access to the services (e.g., HTTP/HTTPS routing).
    *   `vso-auth.yaml`, `vso-connection.yaml`, `vso-secrets.yaml`: These files define Custom Resources for the [Vault Secrets Operator (VSO)](https://developer.hashicorp.com/vault/docs/platform/k8s/vso). They configure how VSO authenticates with Vault (`VaultAuth`), where Vault is located (`VaultConnection`), and which secrets to sync from Vault into Kubernetes `Secret` objects (`VaultSecret`).
    *   `NOTES.txt`: Contains informative notes displayed to the user after a successful Helm chart installation.
    *   `templates/tests/`: This subdirectory holds templated test files (e.g., `ui-test.yaml`, `server-test.yaml`, `jobs-test.yaml`, `nsfwDetector-test.yaml`, `configmap-value-test.yaml`). These are run by `helm test` to verify a release.
*   `tests/`: This top-level directory within the chart contains non-templated test scripts.
    *   `test-golden-files.sh`: A script used for "golden file" testing, which compares rendered Kubernetes manifests against a set of pre-defined "golden" manifests to detect unintended changes. This is particularly useful for ensuring consistency and catching regressions in manifest generation.

### Understanding the File Structure: Why So Many Files?

The number of files in the Helm chart might seem extensive at first, but this modular structure is a key aspect of Helm's design and follows Kubernetes best practices. A well-organized, multi-file chart is significantly easier to manage and scale than a monolithic one, especially for complex applications like Vrooli. Here's why this approach is beneficial for both human developers and AI agents:

*   **Separation of Concerns:** Each file typically addresses a specific Kubernetes resource type (e.g., `deployment.yaml` for Deployments, `service.yaml` for Services) or a particular aspect of the deployment (e.g., `_helpers.tpl` for reusable template logic, `values.yaml` for configuration). This makes the chart easier for anyone (human or AI) to understand, navigate, and maintain.
*   **Modularity and Reusability:** Helper templates in `_helpers.tpl` allow for common patterns (like label generation or name formatting) to be defined once and reused across multiple templates, reducing redundancy and ensuring consistency.
*   **Resource Specialization:** Different Kubernetes resources have distinct schemas, purposes, and lifecycles. For example:
    *   `Deployments` are ideal for stateless applications that can be easily scaled and updated.
    *   `StatefulSets` (like `postgresql-statefulset.yaml` and `redis-statefulset.yaml`) are essential for stateful applications requiring persistent storage and stable network identities (e.g., databases).
    *   The Vault Secrets Operator (VSO) utilizes its own Custom Resource Definitions (`VaultAuth`, `VaultConnection`, `VaultSecret`), which are naturally managed in separate files according to their specific schemas.
*   **Configuration Abstraction:** The template files (`templates/`) define the *structure* and *logic* of your application's deployment, while `values.yaml` (and its environment-specific overrides like `values-dev.yaml` and `values-prod.yaml`) provide the *data* and *configuration parameters*. This clear separation allows for deploying the same application with different settings (e.g., for dev, staging, prod) without modifying the core templates.
*   **Targeted Testing:** Test definitions are logically separated:
    *   `templates/tests/` for Helm's built-in testing framework, allowing for tests that are templatized and run as part of the Helm lifecycle.
    *   `tests/` (at the chart root) for broader, potentially non-templated testing mechanisms like the `test-golden-files.sh` script.
*   **Scalability and Maintainability:** As your application grows more complex, this organized structure scales more effectively than monolithic configuration files. It's easier to add new components, modify existing ones, or troubleshoot issues when concerns are clearly delineated. For AI agents, this means more precise targeting of files for modifications or analysis.
*   **Improved AI Interaction:** For AI agents like myself, a well-structured chart with clear separation of concerns is crucial. It allows for more accurate file identification, easier understanding of resource relationships, and more precise code generation or modification. Instead of parsing a massive, complex file, I can focus on the specific template or value file relevant to the task at hand.

In essence, the Helm chart's file organization promotes clarity, maintainability, and adherence to Kubernetes conventions. This structured approach is vital for efficient and reliable management of complex applications by both human operators and AI-driven automation.

### Installing the Chart

To deploy the Vrooli application using this Helm chart, you will use commands like `helm install` or `helm upgrade --install`. Detailed examples for development and production deployments, along with other essential Helm and kubectl commands, are provided in the "Common Helm & Kubernetes Commands" section below.

Generally, the process involves:
1.  Ensuring your `kubectl` is configured to point to the correct Kubernetes cluster (local Minikube, staging, or production).
2.  Customizing the appropriate values file (`values-dev.yaml` for development, `values-prod.yaml` for production) to match your environment's specific needs (e.g., image tags, resource limits, ingress hostnames, secret paths in Vault).
3.  Running the `helm install` or `helm upgrade --install` command, specifying your release name, the chart path (`k8s/chart/`), and the relevant values files.

For instance, the command structure will look similar to this (refer to the common commands section for exact examples):
`helm upgrade --install <release-name> k8s/chart/ -f k8s/chart/values.yaml -f k8s/chart/values-<env>.yaml --namespace <target-namespace> --create-namespace`

**Important:**
*   For **production deployments**, always use `values-prod.yaml` and double-check all configurations, especially image tags, resource allocations, secret paths, and external endpoints.
*   For **development deployments** (e.g., to Minikube or a staging cluster), use `values-dev.yaml`. It's also common to have a `values-local.yaml` (gitignored) for individual developer overrides during local testing.

### Uninstalling the Chart

To uninstall a release (e.g., `vrooli-dev` from the `staging` namespace):
```bash
helm uninstall vrooli-dev --namespace staging
# For production:
# helm uninstall vrooli-prod --namespace production
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
| `services.ui.tag`                     | Image tag for UI service                                                    | `dev` (typically overridden by env values)  |
| `services.ui.port`                    | Container port for UI service                                               | `3000`                                      |
| `services.ui.probes.livenessPath`     | Liveness probe HTTP path for UI service                                     | `/` (or specific health endpoint)           |
| `services.ui.probes.readinessPath`    | Readiness probe HTTP path for UI service                                    | `/` (or specific health endpoint)           |
| `services.server.repository`          | Image name (without registry) for Server service                          | `server`                                    |
| `services.server.tag`                 | Image tag for Server service                                                | `dev` (typically overridden by env values)  |
| `services.server.port`                | Container port for Server service                                           | `5329`                                      |
| `services.server.probes.livenessPath` | Liveness probe HTTP path for Server service                                 | `/healthcheck`                              |
| `services.server.probes.readinessPath`| Readiness probe HTTP path for Server service                                | `/healthcheck`                              |
| `services.jobs.repository`            | Image name (without registry) for Jobs service                            | `jobs`                                      |
| `services.jobs.tag`                   | Image tag for Jobs service                                                  | `dev` (typically overridden by env values)  |
| `services.jobs.probes.livenessPath`   | Liveness probe HTTP path for Jobs service                                   | `/healthcheck` (if applicable)              |
| `services.jobs.probes.readinessPath`  | Readiness probe HTTP path for Jobs service                                  | `/healthcheck` (if applicable)              |
| `config.env`                          | Environment setting (e.g., development, production)                       | `development`                               |
| `secrets`                             | Deprecated in favor of VSO. Defines Kubernetes Secrets directly.            | `{}` (Prefer VSO for secret management)     |
| `persistence.postgres.enabled`        | Enable PersistentVolumeClaim for PostgreSQL                                 | `true`                                      |
| `persistence.postgres.size`           | Size for PostgreSQL PVC                                                     | `1Gi`                                       |
| `persistence.postgres.storageClass`   | StorageClass for PostgreSQL PVC (e.g., `gp2`, `standard`). Omit for default. | `""`                                        |
| `persistence.redis.enabled`           | Enable PersistentVolumeClaim for Redis                                      | `true`                                      |
| `persistence.redis.size`              | Size for Redis PVC                                                          | `512Mi`                                     |
| `persistence.redis.storageClass`      | StorageClass for Redis PVC. Omit for default.                               | `""`                                        |
| `ingress.enabled`                     | Enable Ingress resource                                                     | `false` (typically true for prod/staging)   |
| `ingress.className`                   | Ingress controller class name (e.g., `nginx`, `traefik`)                    | `""` (set if required by your Ingress controller) |
| `ingress.hosts`                       | Array of host rules for Ingress. Each host entry includes `host` and `paths`. | `[]`                                        |
| `ingress.tls`                         | Array of TLS configurations for Ingress, including `secretName` and `hosts`.  | `[]`                                        |
| `vso.enabled`                         | Enable Vault Secrets Operator integration                                   | `true`                                      |
| `vso.vaultAddr`                       | Address of the Vault instance                                               | `http://vault.vault.svc.cluster.local:8200` |
| `vso.k8sAuthMount`                    | Path where Kubernetes auth method is mounted in Vault                       | `kubernetes`                                |
| `vso.k8sAuthRole`                     | Vault role for VSO to assume                                                | `vrooli-app`                                |
| `vso.secrets.app.enabled`             | Enable syncing general app secrets via VSO                                  | `true`                                      |
| `vso.secrets.app.vaultPath`           | Vault path for general app secrets (e.g., `secret/data/vrooli/app`)         | `secret/data/vrooli/app`                    |
| `vso.secrets.app.k8sSecretName`       | Kubernetes Secret name for general app secrets                              | `vrooli-app-secrets`                        |
| `vso.secrets.postgres.enabled`        | Enable syncing PostgreSQL credentials via VSO                               | `true`                                      |
| `vso.secrets.postgres.vaultPath`      | Vault path for PostgreSQL credentials                                       | `secret/data/vrooli/postgres`               |
| `vso.secrets.postgres.k8sSecretName`  | Kubernetes Secret name for PostgreSQL credentials                           | `vrooli-postgres-creds`                     |
| `vso.secrets.redis.enabled`           | Enable syncing Redis credentials via VSO                                    | `true`                                      |
| `vso.secrets.redis.vaultPath`         | Vault path for Redis credentials                                            | `secret/data/vrooli/redis`                  |
| `vso.secrets.redis.k8sSecretName`     | Kubernetes Secret name for Redis credentials                                | `vrooli-redis-creds`                        |

*(This is a subset of parameters. Refer to `k8s/chart/values.yaml`, `values-dev.yaml`, and `values-prod.yaml` for all options and their detailed comments.)*

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
        *   Define which secrets to sync under `.Values.vso.secrets` in your `values.yaml`. For each entry, you'll specify the `vaultPath` (where the secret lives in Vault), the `k8sSecretName` (the name of the Kubernetes `Secret` VSO will create), and optionally `dataMappings` if you need to rename keys from Vault to the K8s Secret (see "Local Development Setup" for a `dataMappings` example). The `templates/vso-secrets.yaml` template iterates through these configurations.
    *   **Workflow:** When deployed, this chart will create `VaultConnection`, `VaultAuth`, and `VaultSecret` custom resources based on the templates in `k8s/chart/templates/`. The VSO controller watches these resources, authenticates to Vault, fetches the specified secrets, and automatically creates or updates standard Kubernetes `Secret` objects in your release namespace.
    *   **Application Pods:** The application deployments (e.g., `deployment.yaml`, `postgresql-statefulset.yaml`, `redis-statefulset.yaml`) are configured to mount these VSO-managed Kubernetes `Secret` objects to obtain their credentials and configuration.
    *   **Vault Population:** You are responsible for populating the actual secret data into the correct paths within your HashiCorp Vault instance.
    *   This approach centralizes secret management in Vault and aligns with best practices. Refer to the comments in `values.yaml` under the `vso` section and the VSO documentation for more details.
    *   The Kubernetes documentation on [Good practices for Kubernetes Secrets](https://kubernetes.io/docs/concepts/security/secrets-good-practices/) remains a valuable resource for understanding underlying concepts.
*   **Health Checks & Probes:** Ensure that the liveness and readiness probes defined in your Helm templates (e.g., in `templates/deployment.yaml`, and configurable via `services.<name>.probes` in `values.yaml`) correctly point to health check endpoints in your applications. The paths like `/healthcheck` or `/` are common defaults but might need adjustment based on your application's specific health endpoints.
*   **Resource Allocation:** The CPU and memory `requests` and `limits` defined in the chart's templates (and configurable via `services.<name>.resources` in `values.yaml` or environment-specific values files) are crucial for stable operation. Monitor your application's performance and adjust these as needed for each environment.
*   **Stateful Services (PostgreSQL, Redis):**
    The chart includes templates for deploying PostgreSQL and Redis as stateful applications using Kubernetes `StatefulSet` resources (`k8s/chart/templates/postgresql-statefulset.yaml`, `k8s/chart/templates/redis-statefulset.yaml`) and corresponding `Service` definitions (`k8s/chart/templates/postgresql-service.yaml`, `k8s/chart/templates/redis-service.yaml`).
    PersistentVolumeClaims (PVCs) are configured via `k8s/chart/templates/pvc.yaml` and enabled/sized through the `persistence` section in your `values.yaml` file (e.g., `persistence.postgres.enabled`, `persistence.redis.enabled`).
    This setup ensures that your databases have stable network identifiers and persistent storage, which is crucial for data integrity. Ensure you configure:
    1.  Their respective sections within `values.yaml` (under `services.postgres` and `services.redis` if they are managed like other services, or dedicated sections like `postgresql` and `redis` if structured differently in your values) for image, port, resources, and any specific environment variables. Check your `values.yaml` for the exact structure.
    2.  The `replicaCount` for `postgres` and `redis` (typically 1 for simple setups, but can be configured for replication if the images and configurations support it). These might be controlled under `replicaCount.postgres` and `replicaCount.redis` or within their specific service blocks in `values.yaml`.
    Alternatively, if you are using external database services (e.g., managed cloud databases), ensure the chart reflects this:
    *   Set `persistence.postgres.enabled: false` and `persistence.redis.enabled: false` in your values files to prevent unused PVC creation.
    *   If the chart deploys PostgreSQL/Redis pods by default (check `services.postgres.enabled` or similar in `values.yaml`), set these to `false` as well.
    *   Manage connection strings to your external databases via secrets (ideally through VSO).

*   **NSFW Detector GPU Usage (if applicable):**
    If the `nsfwDetector` service is part of your stack and can use GPUs:
    -   This requires your Kubernetes nodes to have GPUs and the appropriate device plugins (e.g., NVIDIA device plugin) installed and configured.
    -   Enable GPU usage by setting the relevant flags in your values file (e.g., `services.nsfwDetector.gpu.enabled: true`).
    -   Optionally, adjust GPU type (e.g., `services.nsfwDetector.gpu.type: "nvidia.com/gpu"`) and count.

This Helm chart provides a structured and maintainable way to manage your Kubernetes deployments as the Vrooli application evolves.

## Common Helm & Kubernetes Commands

This section lists common commands useful for managing the Vrooli Helm chart and interacting with your Kubernetes deployments.

**Key Helm Commands for Chart Management:**

Ensure your `kubectl` context is pointing to the correct cluster before running installation or upgrade commands.

*   **Lint the Chart:**
    Checks the chart for syntax errors and adherence to best practices.
    ```bash
    helm lint k8s/chart/
    ```

*   **Template the Chart (Dry Run - Local Render):**
    Renders the templates locally and prints the YAML output. Useful for debugging what Kubernetes manifests will be generated.
    ```bash
    # Example for development values in 'staging' namespace
    helm template vrooli-dev k8s/chart/ -f k8s/chart/values.yaml -f k8s/chart/values-dev.yaml --namespace staging > rendered-dev-manifests.yaml
    ```

*   **Dry Run Install/Upgrade (Server-Side Validation):**
    Simulates an install or upgrade by sending the chart to the Kubernetes API server for validation, without actually deploying resources. This is useful for catching structural errors in your chart or values before a live deployment attempt.
    ```bash
    # Example for development values in 'staging' namespace
    helm upgrade --install vrooli-dev k8s/chart/ \
      -f k8s/chart/values.yaml \
      -f k8s/chart/values-dev.yaml \
      --namespace staging --create-namespace --dry-run --debug
    
    # Example for production values in 'production' namespace
    helm upgrade --install vrooli-prod k8s/chart/ \
      -f k8s/chart/values.yaml \
      -f k8s/chart/values-prod.yaml \
      --namespace production --create-namespace --dry-run --debug
    ```

*   **Development Deployment (Install/Upgrade):**
    Deploys or updates the application for a development/staging environment. The `--create-namespace` flag will create the namespace if it doesn't exist.
    ```bash
    helm upgrade --install vrooli-dev k8s/chart/ \
      -f k8s/chart/values.yaml \
      -f k8s/chart/values-dev.yaml \
      --namespace staging --create-namespace
    ```

*   **Production Deployment (Install/Upgrade):**
    Deploys or updates the application for a production environment. **Ensure `values-prod.yaml` is thoroughly reviewed and configured.**
    ```bash
    helm upgrade --install vrooli-prod k8s/chart/ \
      -f k8s/chart/values.yaml \
      -f k8s/chart/values-prod.yaml \
      --namespace production --create-namespace
    ```

*   **Run Helm Tests:**
    Executes the tests defined in `k8s/chart/templates/tests/` against a deployed release.
    ```bash
    # Example for 'vrooli-dev' release in 'staging' namespace
    helm test vrooli-dev --namespace staging
    ```

*   **Check Release Status:**
    Displays the status of a deployed release.
    ```bash
    helm status vrooli-dev --namespace staging
    ```

*   **List Releases:**
    Lists all Helm releases in a specific namespace or all namespaces.
    ```bash
    helm list -n staging
    helm list --all-namespaces
    ```

*   **Uninstall a Release:**
    Removes all resources associated with a Helm release.
    ```bash
    helm uninstall vrooli-dev --namespace staging
    helm uninstall vrooli-prod --namespace production
    ```

**Essential Kubectl Commands for Inspection:**

Ensure your `kubectl` context is pointing to the correct cluster. Replace `<your-namespace>` with the target namespace (e.g., `staging`, `production`).

*   **Get All Resources in Namespace:**
    ```bash
    kubectl get all -n <your-namespace>
    ```
*   **Get Pods:**
    ```bash
    kubectl get pods -n <your-namespace>
    kubectl get pods -n <your-namespace> -o wide # For more details like IP and Node
    ```
*   **View Pod Logs:**
    ```bash
    kubectl logs <pod-name> -n <your-namespace>
    kubectl logs <pod-name> -n <your-namespace> -f # To follow logs
    kubectl logs <pod-name> -c <container-name> -n <your-namespace> # If pod has multiple containers
    kubectl logs -l app.kubernetes.io/name=vrooli -l app.kubernetes.io/component=server -n <your-namespace> -f --tail=100 # Follow logs for all server pods
    ```
*   **Describe a Resource (e.g., Pod, Service, Deployment):** Provides detailed information about a resource, useful for troubleshooting. Includes events, current status, and configuration.
    ```bash
    kubectl describe pod <pod-name> -n <your-namespace>
    kubectl describe service <service-name> -n <your-namespace>
    ```
*   **Execute a Command in a Pod (Shell Access):**
    ```bash
    kubectl exec -it <pod-name> -n <your-namespace> -- /bin/sh # Or /bin/bash
    ```
*   **Port Forward to a Pod/Service:** Access a pod or service directly on your local machine.
    ```bash
    kubectl port-forward pod/<pod-name> <local-port>:<pod-port> -n <your-namespace>
    kubectl port-forward service/<service-name> <local-port>:<service-port> -n <your-namespace>
    # Example: Forward local port 8080 to the UI service's port 3000
    # kubectl port-forward service/vrooli-dev-ui 8080:3000 -n staging
    ```
*   **Get ConfigMaps or Secrets:**
    ```bash
    kubectl get configmaps -n <your-namespace>
    kubectl get secrets -n <your-namespace>
    kubectl get secret <secret-name> -n <your-namespace> -o yaml # To view secret content (often base64 encoded)
    ```

**Deploying the Vrooli Chart Locally:**

This section assumes you are deploying to a local Minikube setup, potentially with an in-cluster Vault for secrets as configured by `scripts/main/setup.sh --target k8s-cluster`.

*   **Secrets Management (Vault Integration):**
    *   **Prerequisites:**
        *   A running HashiCorp Vault instance accessible from your Minikube cluster.
        *   The Vault Secrets Operator installed in Minikube.
        *   (The `scripts/main/setup.sh --target k8s-cluster` command handles this if `--secrets-source vault` is used.)
    *   **Chart Configuration for VSO (in `values-dev.yaml` or a custom values file for local):**
        *   Ensure `.Values.vso.enabled: true`.
        *   Set `.Values.vso.vaultAddr` (e.g., `http://vault.vault.svc.cluster.local:8200` for the typical dev setup using the in-cluster Vault service).
        *   Configure `.Values.vso.k8sAuthRole` (e.g., `vrooli-app`). This role must be configured in Vault and bound to the Kubernetes service account used by the Vault Secrets Operator or your application pods, depending on the auth flow.
        *   Define the secrets to sync under `.Values.vso.secrets`. For each secret (e.g., `redis`, `postgres`, `app`):
            *   Set `enabled: true`.
            *   Specify `vaultPath`: The path to the secret in Vault's K/V store (e.g., `secret/data/vrooli/redis`).
            *   Specify `k8sSecretName`: The name of the Kubernetes `Secret` that VSO will create/manage in the release namespace.
            *   Optionally use `dataMappings` to map keys from the Vault secret to different key names in the Kubernetes `Secret`. This is useful if your application expects specific environment variable names.
        Example snippet for `values-dev.yaml` or a local override file:
            ```yaml
            # values-dev.yaml (or values-local.yaml)
            vso:
              enabled: true
              vaultAddr: "http://vault.vault.svc.cluster.local:8200" # Default for in-cluster dev Vault
              k8sAuthMount: "kubernetes" # Default k8s auth mount path in Vault
              k8sAuthRole: "vrooli-app"  # Role configured in Vault for your app/VSO
              secrets:
                redis:
                  enabled: true
                  vaultPath: "secret/data/vrooli/redis" # Example path for KV v2
                  k8sSecretName: "vrooli-redis-creds"
                  # Example: if Vault stores { "password": "..." } and app needs REDIS_PASSWORD
                  dataMappings:
                    - vaultKey: "password"      # Key in Vault secret
                      k8sKey: "REDIS_PASSWORD"  # Key in the created K8s Secret
                postgres:
                  enabled: true
                  vaultPath: "secret/data/vrooli/postgres"
                  k8sSecretName: "vrooli-postgres-creds"
                  dataMappings:
                    - vaultKey: "POSTGRES_USER"
                      k8sKey: "POSTGRES_USER"
                    - vaultKey: "POSTGRES_PASSWORD"
                      k8sKey: "POSTGRES_PASSWORD"
                    # Add other necessary mappings like POSTGRES_DB, POSTGRES_HOST if managed in Vault
                app: # General application secrets
                  enabled: true
                  vaultPath: "secret/data/vrooli/app"
                  k8sSecretName: "vrooli-app-secrets"
                  # Example:
                  # dataMappings:
                  #   - vaultKey: "someApiKey"
                  #     k8sKey: "SOME_API_KEY"
                  #   - vaultKey: "anotherSetting"
                  #     k8sKey: "ANOTHER_SETTING"

                # Example for Docker Hub credentials if needed for private images
                # dockerhub:
                #   enabled: true
                #   vaultPath: "secret/data/vrooli/dockerhub" # Store .dockerconfigjson content here as a value
                #   k8sSecretName: "dockerhub-credentials"
                #   k8sSecretType: "kubernetes.io/dockerconfigjson" # Special type for image pull secrets
                #   # VSO needs to be configured to handle this appropriately, often by having a single key in Vault
                #   # whose value is the entire .dockerconfigjson string.
                #   # dataMappings:
                #   #   - vaultKey: "dockerconfigjson" # Key in Vault holding the JSON string
                #   #     k8sKey: ".dockerconfigjson" # Required key in the K8s secret of this type
            ```
    *   **Populate Secrets in Vault:** Before deploying the chart, ensure the actual secret data is populated in your Vault instance at the specified paths (e.g., using `vault kv put secret/vrooli/redis password=yourpassword`). Remember KV v2 paths are prefixed with `secret/data/`.
    *   **Deployment:** Deploy the chart using `helm upgrade --install` with your development values file. The VSO will watch the `VaultSecret` custom resources created by the chart and then sync the secrets from Vault to standard Kubernetes `Secret` objects. Application pods will then mount these Kubernetes `Secret` objects.
*   **Production Secrets Consideration:**
    *   The local development Vault setup (often using Vault's `dev` server mode, which is auto-unsealed and uses in-memory storage by default) is **NOT SUITABLE FOR PRODUCTION.**
    *   Production deployments must use a hardened, HA Vault setup. VSO in the production cluster will connect to this production Vault.

This Helm chart provides a structured and maintainable way to manage your Kubernetes deployments as the Vrooli application evolves. 