# Vrooli Helm Chart

This Helm chart deploys the Vrooli microservices stack to Kubernetes.

## Prerequisites

- Kubernetes 1.19+ cluster
- Helm 3.x installed
- Container images (`ui`, `server`, `jobs`, etc.) available in your configured container registry (see `image.registry` value)

## Chart Structure

```
k8s/chart/vrooli/
  Chart.yaml           # Chart metadata
  values.yaml          # Default configuration values
  values-dev.yaml      # Overrides for development environment
  values-prod.yaml     # Overrides for production environment
  .helmignore          # Patterns to exclude from chart
  templates/           # Kubernetes manifest templates
    _helpers.tpl       # Naming helpers and standard labels
    deployment.yaml    # Deployments for each service
    service.yaml       # Services for each service
    configmap.yaml     # ConfigMap for non-sensitive config
    secret.yaml        # Secret for sensitive data
    pvc.yaml           # PersistentVolumeClaims
    ingress.yaml       # Ingress definitions
    NOTES.txt          # Post-installation instructions
    ui-test.yaml       # Example Helm test hook
```

## Installing the Chart

### Development
To install the chart with the release name `vrooli-dev` into the default namespace, using development values:
```bash
helm install vrooli-dev k8s/chart/vrooli \
  -f k8s/chart/vrooli/values.yaml \
  -f k8s/chart/vrooli/values-dev.yaml
```

### Production
To install the chart with the release name `vrooli-prod` into the default namespace, using production-specific values layered over the base values:
```bash
helm install vrooli-prod k8s/chart/vrooli \
  -f k8s/chart/vrooli/values.yaml \
  -f k8s/chart/vrooli/values-prod.yaml
```
**Note:** Ensure you have reviewed and customized `values-prod.yaml` (especially image tags, hostnames, secrets, and resource allocations) before deploying to production.

## Uninstalling the Chart

```bash
helm uninstall vrooli-dev
helm uninstall vrooli-prod
```

## Configuration

The following table lists the configurable parameters of the Vrooli chart and their default values as defined in `values.yaml`.

| Parameter                             | Description                                                                 | Default Value                               |
| ------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------- |
| `nameOverride`                        | String to override the chart name component of resource names               | `""`                                        |
| `fullnameOverride`                    | String to fully override the `Release.Name-chartName` aresource names       | `""`                                        |
| `image.registry`                      | Global image registry prefix (e.g., `docker.io/myusername`)                 | `"your-registry/your-project"` (FIXME)      |
| `image.pullPolicy`                    | Global image pull policy for all services                                   | `IfNotPresent`                              |
| `replicaCount.ui`                     | Number of replicas for the UI service                                       | `1`                                         |
| `replicaCount.server`                 | Number of replicas for the Server service                                   | `1`                                         |
| `replicaCount.jobs`                   | Number of replicas for the Jobs service                                     | `1`                                         |
| `replicaCount.adminer`                | Number of replicas for the Adminer service (primarily for dev)              | `1`                                         |
| `replicaCount.postgres`               | Number of replicas for PostgreSQL (if managed by this chart, requires StatefulSet) | `1`                                         |
| `replicaCount.redis`                  | Number of replicas for Redis (if managed by this chart, requires StatefulSet) | `1`                                         |
| `replicaCount.nsfwDetector`           | Number of replicas for the NSFW Detector service                            | `1` (but disabled by default)               |
| `services.ui.repository`              | Image name (without registry) for UI service                              | `ui`                                        |
| `services.ui.tag`                     | Image tag for UI service                                                    | `dev`                                       |
| `services.ui.port`                    | Container port for UI service                                               | `3000`                                      |
| `services.ui.probes.livenessPath`     | Liveness probe HTTP path for UI service                                     | `/healthcheck`                              |
| `services.ui.probes.readinessPath`    | Readiness probe HTTP path for UI service                                    | `/healthcheck`                              |
| `services.ui.resources.requests.cpu`  | CPU request for UI service                                                  | `100m`                                      |
| `services.ui.resources.requests.memory`| Memory request for UI service                                               | `128Mi`                                     |
| `services.ui.resources.limits.cpu`    | CPU limit for UI service                                                    | `200m`                                      |
| `services.ui.resources.limits.memory` | Memory limit for UI service                                                 | `256Mi`                                     |
| `services.server.repository`          | Image name (without registry) for Server service                          | `server`                                    |
| `services.server.tag`                 | Image tag for Server service                                                | `dev`                                       |
| `services.server.port`                | Container port for Server service                                           | `5329`                                      |
| `services.server.probes.livenessPath` | Liveness probe HTTP path for Server service                                 | `/healthcheck`                              |
| `services.server.probes.readinessPath`| Readiness probe HTTP path for Server service                                | `/healthcheck`                              |
| `services.server.resources.requests.cpu`| CPU request for Server service                                              | `200m`                                      |
| `services.server.resources.requests.memory`| Memory request for Server service                                           | `256Mi`                                     |
| `services.server.resources.limits.cpu`| CPU limit for Server service                                                | `400m`                                      |
| `services.server.resources.limits.memory`| Memory limit for Server service                                             | `512Mi`                                     |
| `services.jobs.repository`            | Image name (without registry) for Jobs service                            | `jobs`                                      |
| `services.jobs.tag`                   | Image tag for Jobs service                                                  | `dev`                                       |
| `services.jobs.port`                  | Container port for Jobs service                                             | `9230`                                      |
| `services.jobs.probes.livenessPath`   | Liveness probe HTTP path for Jobs service                                   | `/healthcheck`                              |
| `services.jobs.probes.readinessPath`  | Readiness probe HTTP path for Jobs service                                  | `/healthcheck`                              |
| `services.jobs.resources.requests.cpu`| CPU request for Jobs service                                                | `100m`                                      |
| `services.jobs.resources.requests.memory`| Memory request for Jobs service                                             | `128Mi`                                     |
| `services.jobs.resources.limits.cpu`  | CPU limit for Jobs service                                                  | `200m`                                      |
| `services.jobs.resources.limits.memory`| Memory limit for Jobs service                                               | `256Mi`                                     |
| `services.nsfwDetector.enabled`       | Enable the NSFW Detector service                                            | `false`                                     |
| `services.nsfwDetector.repository`    | Image name for NSFW Detector (e.g., `steelcityamir/safe-content-ai`)        | `steelcityamir/safe-content-ai`             |
| `services.nsfwDetector.tag`           | Image tag for NSFW Detector                                                 | `1.1.0`                                     |
| `services.nsfwDetector.port`          | Container port for NSFW Detector                                            | `8000`                                      |
| `services.nsfwDetector.probes.useTcpSocket` | Use TCP socket probe instead of HTTP for NSFW Detector                      | `true`                                      |
| `services.nsfwDetector.probes.initialDelaySeconds` | Initial delay for NSFW Detector probes                                      | `60`                                        |
| `services.nsfwDetector.probes.periodSeconds` | Period for NSFW Detector probes                                             | `30`                                        |
| `services.nsfwDetector.probes.timeoutSeconds` | Timeout for NSFW Detector probes                                            | `10`                                        |
| `services.nsfwDetector.probes.failureThreshold` | Failure threshold for NSFW Detector probes                                  | `3`                                         |
| `services.nsfwDetector.resources.requests.cpu`| CPU request for NSFW Detector                                               | `200m`                                      |
| `services.nsfwDetector.resources.requests.memory`| Memory request for NSFW Detector                                            | `512Mi`                                     |
| `services.nsfwDetector.resources.limits.cpu`| CPU limit for NSFW Detector                                                 | `500m`                                      |
| `services.nsfwDetector.resources.limits.memory`| Memory limit for NSFW Detector                                              | `1Gi`                                       |
| `services.nsfwDetector.gpu.enabled`   | Enable GPU resources for NSFW Detector                                      | `false`                                     |
| `services.nsfwDetector.gpu.type`      | GPU resource type (e.g., `nvidia.com/gpu`) - used if GPU enabled            | (not set, defaults to `nvidia.com/gpu`)     |
| `services.nsfwDetector.gpu.count`     | Number of GPUs to request - used if GPU enabled                             | (not set, defaults to `1`)                  |
| `config.projectDir`                   | General project directory path (used as an example env var)                 | `/srv/app`                                  |
| `config.env`                          | Environment setting (e.g., development, production)                       | `development`                               |
| `secrets`                             | Key-value pairs for Kubernetes Secrets (sensitive data). Empty by default.  | `{}`                                        |
| `persistence.postgres.enabled`        | Enable PersistentVolumeClaim for PostgreSQL                                 | `true`                                      |
| `persistence.postgres.size`           | Size for PostgreSQL PVC                                                     | `1Gi`                                       |
| `persistence.postgres.storageClass`   | StorageClass for PostgreSQL PVC (uses cluster default if `""`)              | `""`                                        |
| `persistence.redis.enabled`           | Enable PersistentVolumeClaim for Redis                                      | `true`                                      |
| `persistence.redis.size`              | Size for Redis PVC                                                          | `512Mi`                                     |
| `persistence.redis.storageClass`      | StorageClass for Redis PVC (uses cluster default if `""`)                   | `""`                                        |
| `persistence.nsfwDetector.enabled`    | Enable PersistentVolumeClaim for NSFW Detector                              | `false`                                     |
| `persistence.nsfwDetector.size`       | Size for NSFW Detector PVC                                                  | (not set by default, e.g. `5Gi` in prod)    |
| `persistence.nsfwDetector.storageClass`| StorageClass for NSFW Detector PVC (uses cluster default if `""`)           | `""`                                        |
| `persistence.ui.enabled`              | Enable PVC for UI service (typically false)                                 | `false`                                     |
| `persistence.server.enabled`          | Enable PVC for Server service (typically false)                             | `false`                                     |
| `persistence.jobs.enabled`            | Enable PVC for Jobs service (typically false)                               | `false`                                     |
| `persistence.adminer.enabled`         | Enable PVC for Adminer service (typically false)                            | `false`                                     |
| `ingress.enabled`                     | Enable Ingress resource                                                     | `false`                                     |
| `ingress.annotations`                 | Annotations for Ingress resource                                            | `{}`                                        |
| `ingress.hosts`                       | Array of host rules for Ingress. Each item: `{ host: string, paths: [{ path: string, pathType: string, service: string, port: number }] }` | `[]`                                        |
| `ingress.tls`                         | Array of TLS configurations. Each item: `{ secretName: string, hosts: [string] }` | `[]`                                        |

Refer to `values.yaml` for the exact structure and for any values not explicitly listed here. Environment-specific overrides are typically placed in `values-dev.yaml` or `values-prod.yaml`.

---

**Note on Stateful Services (PostgreSQL, Redis):**

This chart includes PVC configuration for PostgreSQL and Redis in `values.yaml` (enabled by default). However, the base chart templates **do not** include `StatefulSet` definitions for these services.
If you intend to deploy PostgreSQL or Redis as part of this Helm release, you will need to:
1. Add `StatefulSet` and `Service` manifest files to the `templates/` directory for each.
2. Configure their respective sections within `.Values.services` (or a new dedicated section) in `values.yaml` so that the `StatefulSet` templates can access image, port, resources, and environment variable configurations.
3. Ensure the `replicaCount` for `postgres` and `redis` are set appropriately.

Alternatively, if you are using external database services, ensure `persistence.postgres.enabled` and `persistence.redis.enabled` are set to `false` to prevent unused PVC creation, or manage their connection strings via the `secrets` value.

**Note on NSFW Detector GPU Usage:**

The `nsfwDetector` service can optionally be configured to use GPU resources for better performance. This requires your Kubernetes nodes to have GPUs and the appropriate device plugins (e.g., NVIDIA device plugin) installed and configured. To enable GPU usage:
- Set `services.nsfwDetector.gpu.enabled: true` in your values file.
- Optionally, adjust `services.nsfwDetector.gpu.type` (e.g., `nvidia.com/gpu`) and `services.nsfwDetector.gpu.count`.

--- 