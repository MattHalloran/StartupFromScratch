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
│   │   ├── ingress.yaml    # For exposing services externally
│   │   ├── pgo-postgrescluster.yaml    # CR for CrunchyData PostgreSQL Operator
│   │   ├── spotahome-redis-failover.yaml # CR for Spotahome Redis Operator
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
    *   `pgo-postgrescluster.yaml`: Defines a `PostgresCluster` Custom Resource for the [CrunchyData PostgreSQL Operator (PGO)](https://www.crunchydata.com/products/crunchy-postgresql-for-kubernetes/). PGO manages the deployment, high availability, backups, and other operational aspects of PostgreSQL.
    *   `spotahome-redis-failover.yaml`: Defines a `RedisFailover` Custom Resource for the [Spotahome Redis Operator](https://github.com/spotahome/redis-operator). This operator manages a Redis master-replica setup with Sentinel for automatic failover.
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
    *   Stateful applications like PostgreSQL and Redis are managed by dedicated Kubernetes Operators (CrunchyData PGO for PostgreSQL, Spotahome Redis Operator for Redis). These operators utilize Custom Resource Definitions (`PostgresCluster`, `RedisFailover`) defined in `pgo-postgrescluster.yaml` and `spotahome-redis-failover.yaml` respectively. This approach encapsulates complex stateful set management, HA, and operational logic within the operators.
    *   The Vault Secrets Operator (VSO) utilizes its own Custom Resource Definitions (`VaultAuth`, `VaultConnection`, `VaultSecret`), which are naturally managed in separate files according to their specific schemas.
*   **Configuration Abstraction:** The template files (`templates/`) define the *structure* and *logic* of your application's deployment, including the Custom Resources for operators. The `values.yaml` (and its environment-specific overrides like `values-dev.yaml` and `values-prod.yaml`) provide the *data* and *configuration parameters* for these operators and other resources. This clear separation allows for deploying the same application with different settings (e.g., for dev, staging, prod) without modifying the core templates.
*   **Targeted Testing:** Test definitions are logically separated:
    *   `templates/tests/` for Helm's built-in testing framework, allowing for tests that are templatized and run as part of the Helm lifecycle.
    *   `tests/` (at the chart root) for broader, potentially non-templated testing mechanisms like the `test-golden-files.sh` script.
*   **Scalability and Maintainability:** As your application grows more complex, this organized structure scales more effectively than monolithic configuration files. It's easier to add new components, modify existing ones, or troubleshoot issues when concerns are clearly delineated. For AI agents, this means more precise targeting of files for modifications or analysis.
*   **Improved AI Interaction:** For AI agents like myself, a well-structured chart with clear separation of concerns is crucial. It allows for more accurate file identification, easier understanding of resource relationships, and more precise code generation or modification. Instead of parsing a massive, complex file, I can focus on the specific template or value file relevant to the task at hand.

In essence, the Helm chart's file organization promotes clarity, maintainability, and adherence to Kubernetes conventions. This structured approach is vital for efficient and reliable management of complex applications by both human operators and AI-driven automation.

### Installing the Chart

To deploy the Vrooli application using this Helm chart, you will use commands like `helm install` or `helm upgrade --install`. These commands are orchestrated by our project scripts:
*   **Local Kubernetes Development (e.g., Minikube):** The `scripts/helpers/develop/target/k8s_cluster.sh` script (invoked by `scripts/main/develop.sh --target k8s-cluster`) deploys the chart directly from the `k8s/chart/` source directory. It typically uses `k8s/chart/values.yaml` as the base and applies overrides from `k8s/chart/values-dev.yaml`.
*   **Staging/Production Deployments:** The `scripts/main/deploy.sh -s k8s` script uses a packaged Helm chart (`.tgz` file) that was created by `scripts/main/build.sh`.
    *   The `build.sh` script packages the contents of `k8s/chart/` (including its `values.yaml`).
    *   Crucially, `build.sh` also copies environment-specific values files (e.g., `k8s/chart/values-dev.yaml`, `k8s/chart/values-prod.yaml`) into a separate location within the build artifact (specifically, to `ARTIFACTS_DIR/helm-value-files/`).
    *   The `deploy.sh` script (via `scripts/helpers/deploy/k8s.sh`) then uses the packaged chart (`.tgz`) and applies the appropriate environment-specific values file *from the build artifact* (e.g., `ARTIFACTS_DIR/helm-value-files/values-prod.yaml`) using the `-f` flag.

The general Helm command structure (as used by the scripts) looks similar to this:
`helm upgrade --install <release-name> <path-to-chart-source-or-package> -f <base-values.yaml> -f <environment-specific-values.yaml> --namespace <target-namespace> --create-namespace`

**Key Takeaway for Values Files:**
*   For local development targeting Minikube (via `develop.sh`), customizations are made directly in `k8s/chart/values-dev.yaml`.
*   For staging/production deployments (via `build.sh` then `deploy.sh`), the `values-<env>.yaml` (e.g., `values-prod.yaml`) from the `k8s/chart/` directory at the time of the build is packaged into the deployment artifact and used during the Helm upgrade. Ensure this file is correct before running `build.sh`.

**Important:**
*   For **production deployments** (using `deploy.sh`):
    *   Always ensure the `k8s/chart/values-prod.yaml` in your source code is accurate and committed *before* running `scripts/main/build.sh`. This file's content will be included in the build artifact and used for the production deployment.
    *   Double-check all configurations, especially image tags, resource allocations, secret paths, and external endpoints within this `values-prod.yaml`.
    *   The `scripts/helpers/deploy/k8s.sh` script will abort if it's a production deployment and the corresponding `values-prod.yaml` is not found in the build artifact.
*   For **local development deployments** (e.g., to Minikube via `develop.sh`):
    *   The script uses `k8s/chart/values-dev.yaml` directly from your workspace.

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
| `image.registry`                      | Global image registry (e.g., `docker.io/yourusername`). Combined with service repo names unless repo is a full path. | `docker.io/{{ .Values.dockerhubUsername }}`      |
| `image.pullPolicy`                    | Global image pull policy for all services                                   | `IfNotPresent`                              |
| `replicaCount.ui`                     | Number of replicas for the UI service                                       | `1`                                         |
| `replicaCount.server`                 | Number of replicas for the Server service                                   | `1`                                         |
| `replicaCount.jobs`                   | Number of replicas for the Jobs service                                     | `1`                                         |
| `services.ui.repository`              | Image name or full path for UI service. If name, combined with `image.registry`. | `ui`                                        |
| `services.ui.tag`                     | Image tag for UI service. **Note:** For deployments via `deploy.sh`, this may be overridden by the script itself. See "Image Tag Management" below. | `dev` (typically overridden by env values)  |
| `services.ui.port`                    | Container port for UI service                                               | `3000`                                      |
| `services.ui.probes.livenessPath`     | Liveness probe HTTP path for UI service                                     | `/healthcheck` (or specific health endpoint)|
| `services.ui.probes.readinessPath`    | Readiness probe HTTP path for UI service                                    | `/healthcheck` (or specific health endpoint)|
| `services.server.repository`          | Image name or full path for Server service. If name, combined with `image.registry`. | `server`                                    |
| `services.server.tag`                 | Image tag for Server service. **Note:** For deployments via `deploy.sh`, this may be overridden by the script itself. See "Image Tag Management" below. | `dev` (typically overridden by env values)  |
| `services.server.port`                | Container port for Server service                                           | `5329`                                      |
| `services.server.probes.livenessPath` | Liveness probe HTTP path for Server service                                 | `/healthcheck`                              |
| `services.server.probes.readinessPath`| Readiness probe HTTP path for Server service                                | `/healthcheck`                              |
| `services.jobs.repository`            | Image name or full path for Jobs service. If name, combined with `image.registry`. | `jobs`                                      |
| `services.jobs.tag`                   | Image tag for Jobs service. **Note:** For deployments via `deploy.sh`, this may be overridden by the script itself. See "Image Tag Management" below. | `dev` (typically overridden by env values)  |
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

*(This is a subset of parameters. Refer to `k8s/chart/values.yaml`, and the source `k8s/chart/values-dev.yaml` and `k8s/chart/values-prod.yaml` files for all options and their detailed comments. The environment-specific files are packaged into build artifacts for deployment.)*

### Important Operational Notes (from chart README)

*   **Container Registry & Image Tags:** The Docker image repositories and tags for your services (`server`, `jobs`, `ui`) are primarily configured within the Helm chart's values files.
    *   **Values Files:**
        *   The base `k8s/chart/values.yaml` provides defaults.
        *   Environment-specific overrides (e.g., image tags, replica counts) should be set in `k8s/chart/values-dev.yaml` (for local/Minikube development via `develop.sh`) and `k8s/chart/values-prod.yaml` (for production deployments via `build.sh` and `deploy.sh`).
        *   When `scripts/main/build.sh` runs, it copies the `values-<env>.yaml` files from `k8s/chart/` into the build artifact. The `scripts/main/deploy.sh` script then uses this artifact-bundled `values-<env>.yaml` file.
    *   A global registry is defined in `.Values.image.registry` (e.g., `docker.io/yourusername`).
    *   Ensure these settings point to your actual container registry and the correct image versions for each service and environment.
    *   **Image Tag Management for `deploy.sh`:**
        *   Tags for production deployments are injected into `values-prod.yaml` during the build process when you supply a `--version` flag to `build.sh`. Without `--version`, build.sh uses the version from `package.json` but does not modify Helm chart files.
        *   No script-based `--set` overrides are applied during deployment; Helm uses the tags defined in the values files.
    *Example in `values.yaml` (structure may vary based on chart design):*
    ```yaml
    image:
      registry: "docker.io/{{ .Values.dockerhubUsername }}" # Defaults to Docker Hub, using dockerhubUsername
      pullPolicy: IfNotPresent

    dockerhubUsername: "your_dockerhub_username_here" # Change this to your Docker Hub username

    services:
      server:
        # 'server' will be combined with image.registry: e.g., docker.io/your_dockerhub_username_here/server
        repository: server
        tag: latest
      ui:
        repository: ui
        tag: latest
      nsfwDetector:
        # This is a full path and will be used as-is, ignoring image.registry
        repository: steelcityamir/safe-content-ai
        tag: "1.1.0"
    # ... and so on for other services
    ```
*   **Configuration Values:**
    *   Thoroughly review and customize `k8s/chart/values.yaml`.
    *   For local development via `scripts/main/develop.sh --target k8s-cluster`, edit `k8s/chart/values-dev.yaml` directly.
    *   For staging/production deployments via `scripts/main/deploy.sh`, ensure `k8s/chart/values-prod.yaml` (or `values-staging.yaml`, etc.) is correct in your source code *before* running `scripts/main/build.sh`. The `build.sh` script will package this file into the build artifact, and `deploy.sh` will use that packaged version.
    These files manage settings like database connection strings, API keys, resource requests/limits, replica counts, etc.
*   **Secrets Management (Vault Integration):** This chart is designed to integrate with HashiCorp Vault via the Vault Secrets Operator (VSO) for managing sensitive data.
    *   **Prerequisites:** A running HashiCorp Vault instance and the Vault Secrets Operator must be installed and configured in your Kubernetes cluster.
    *   **Helm Chart Configuration:**
        *   Enable VSO integration by setting `.Values.vso.enabled: true`. This should be done in the appropriate values file (`k8s/chart/values.yaml` or overridden in `k8s/chart/values-<env>.yaml`).
        *   Configure `.Values.vso.vaultAddr` to point to your Vault service.
        *   Specify the Vault role VSO should use via `.Values.vso.k8sAuthRole`.
        *   Define which secrets to sync under `.Values.vso.secrets`.
        *   The `scripts/main/deploy.sh` flow relies on these configurations being correctly set in the `values-<env>.yaml` file that is packaged into the build artifact.
    *   **Workflow:** When deployed (via `develop.sh` for local K8s or `deploy.sh` for other environments), the Helm chart will create `VaultConnection`, `VaultAuth`, and `VaultSecret` custom resources. The VSO controller then syncs secrets.
*   **Health Checks & Probes:** Ensure that the liveness and readiness probes defined in your Helm templates (e.g., in `templates/deployment.yaml`, and configurable via `services.<name>.probes` in `values.yaml`) correctly point to health check endpoints in your applications. The paths like `/healthcheck` or `/` are common defaults but might need adjustment based on your application's specific health endpoints.
*   **Resource Allocation:** The CPU and memory `requests` and `limits` defined in the chart's templates (and configurable via `services.<name>.resources` in `values.yaml` or environment-specific values files) are crucial for stable operation. Monitor your application's performance and adjust these as needed for each environment.
*   **Stateful Services (PostgreSQL, Redis):**
    High availability and lifecycle management for PostgreSQL and Redis are handled by dedicated Kubernetes Operators:
    *   **PostgreSQL:** Managed by the [CrunchyData PostgreSQL Operator (PGO)](https://www.crunchydata.com/products/crunchy-postgresql-for-kubernetes/). Configuration is defined via a `PostgresCluster` Custom Resource, templated in `k8s/chart/templates/pgo-postgrescluster.yaml`. PGO handles instance provisioning, replication, failover, backups (with pgBackRest), and connection pooling (with pgBouncer). Configuration for PGO (instance count, storage, users, backups, etc.) is managed under the `pgoPostgresql` section in your `values.yaml` file.
    *   **Redis:** Managed by the [Spotahome Redis Operator](https://github.com/spotahome/redis-operator). Configuration is defined via a `RedisFailover` Custom Resource, templated in `k8s/chart/templates/spotahome-redis-failover.yaml`. The operator sets up a master-replica Redis deployment with Sentinel for monitoring and automatic failover. Configuration for the Redis Operator (replica counts, storage, auth, Sentinel settings) is managed under the `spotahomeRedis` section in your `values.yaml` file.

    Persistent storage for these operator-managed services is defined within their respective Custom Resource configurations in `values.yaml` and realized by the operators themselves.
    Ensure you configure:
    1.  The `pgoPostgresql` and `spotahomeRedis` sections in your `values.yaml` file (and environment-specific overrides) for images, ports, resources, instance/replica counts, persistence, authentication, and any operator-specific settings.
    Alternatively, if you are using external database services (e.g., managed cloud databases), ensure the chart reflects this:
    *   Set `pgoPostgresql.enabled: false` and `spotahomeRedis.enabled: false` in your values files.
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

*   **Lint the Chart (Source):**
    Checks the chart in your local `k8s/chart/` directory.
    ```bash
    helm lint k8s/chart/
    ```

*   **Template the Chart (Dry Run - Local Render from Source):**
    Renders templates locally from `k8s/chart/` using specified values files. Useful for debugging.
    ```bash
    # Example for development values from source, targeting 'dev' namespace
    helm template vrooli-dev k8s/chart/ -f k8s/chart/values.yaml -f k8s/chart/values-dev.yaml --namespace dev > rendered-dev-manifests.yaml
    ```

*   **Dry Run Install/Upgrade (Server-Side Validation, Simulating `deploy.sh`):**
    This simulates how `scripts/main/deploy.sh` would run, using a *packaged chart* and *specific values file from an artifact*.
    To truly simulate `deploy.sh`, you would first run `scripts/main/build.sh` to create the `.tgz` chart package and the `helm-value-files/` in an artifact structure.
    Then, you would point Helm to the packaged chart and the relevant extracted values file:
    ```bash
    # Assuming build artifacts for version 0.1.0 are in ./build_output/0.1.0/artifacts/
    # And packaged chart is ./build_output/0.1.0/artifacts/k8s-chart-packages/vrooli-0.1.0.tgz
    # And prod values are ./build_output/0.1.0/artifacts/helm-value-files/values-prod.yaml

    # Example for production values from (simulated) artifact, targeting 'production' namespace
    helm upgrade --install vrooli-prod ./build_output/0.1.0/artifacts/k8s-chart-packages/vrooli-0.1.0.tgz \
      -f ./build_output/0.1.0/artifacts/helm-value-files/values-prod.yaml \
      # Add any --set overrides that deploy.sh would add, like image tags
      --set services.server.tag=0.1.0 \ 
      --namespace production --create-namespace --dry-run --debug
    ```

*   **Development Deployment (via `scripts/main/develop.sh`):**
    This script handles deploying the chart directly from your `k8s/chart/` source to Minikube.
    ```bash
    # Example:
    bash scripts/main/develop.sh --target k8s-cluster 
    # This uses k8s/chart/values-dev.yaml by default.
    ```

*   **Staging/Production Deployment (via `scripts/main/deploy.sh -s k8s`):**
    This script uses a packaged chart and values from the build artifact.
    ```bash
    # Example for deploying 'prod' environment, version from $VERSION variable
    # Ensure $VERSION is set, e.g., export VERSION="$(node -p "require('./package.json').version")"
    # export ENVIRONMENT="prod" (or staging)
    # bash scripts/main/deploy.sh -s k8s -e "$ENVIRONMENT" -v "$VERSION"
    # (Example command, check deploy.sh for exact arguments)
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

**Deploying the Vrooli Chart Locally (Using `scripts/main/develop.sh` for Minikube):**

The `scripts/main/develop.sh --target k8s-cluster` command is the primary way to deploy to a local Minikube setup.
*   It uses the Helm chart directly from your `k8s/chart/` source directory.
*   It applies `k8s/chart/values.yaml` and overrides it with `k8s/chart/values-dev.yaml`.
*   It also applies further overrides via `--set` for image tags (setting them to `dev`) and potentially `image.pullPolicy`.

*   **Secrets Management (Vault Integration for Local K8s Development):**
    *   When using `scripts/main/develop.sh --target k8s-cluster` with Vault enabled (via `scripts/main/setup.sh --secrets-source vault`):
        *   The VSO configurations in `k8s/chart/values-dev.yaml` (e.g., `vso.enabled`, `vso.vaultAddr`, `vso.secrets`) are used.
        *   Ensure these point to your local/dev Vault instance and the correct secret paths.

This Helm chart provides a structured and maintainable way to manage your Kubernetes deployments as the Vrooli application evolves. 