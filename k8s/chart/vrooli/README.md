# Vrooli Helm Chart

This Helm chart deploys the Vrooli microservices stack to Kubernetes.

## Prerequisites

- Kubernetes 1.19+ cluster
- Helm 3.x installed
- Container images (`ui`, `server`, `jobs`, etc.) available in your registry

## Chart Structure

```
k8s/chart/vrooli/
  Chart.yaml           # Chart metadata
  values.yaml          # Default configuration values
  values-dev.yaml      # Overrides for development environment
  values-prod.yaml     # Overrides for production environment
  .helmignore          # Patterns to exclude from chart
  templates/           # Kubernetes manifest templates
    _helpers.tpl       # Naming helpers
    deployment.yaml    # Deployments for each service
    service.yaml       # Services for each service
    configmap.yaml     # ConfigMap for non-sensitive config
    secret.yaml        # Secret for sensitive data
    pvc.yaml           # PersistentVolumeClaims
    ingress.yaml       # Ingress definitions
    NOTES.txt          # Post-installation instructions
```

## Installing the Chart

### Development
```bash
helm install vrooli-dev k8s/chart/vrooli \
  -f k8s/chart/vrooli/values.yaml \
  -f k8s/chart/vrooli/values-dev.yaml
```

### Production
```bash
helm install vrooli-prod k8s/chart/vrooli \
  -f k8s/chart/vrooli/values-prod.yaml
```

## Uninstalling the Chart

```bash
helm uninstall vrooli-dev
helm uninstall vrooli-prod
```

## Configuration

Key configurable values (in `values*.yaml`):

- `replicaCount`: replicas per service
- `services`: image repository, tag, port, and resource specs
- `config`: non-sensitive configuration data
- `secrets`: key/value pairs for Kubernetes Secret (sensitive data)
- `persistence`: enable/size/storageClass per stateful service
- `ingress`: enable, annotations, hosts, TLS settings

For detailed options, consult `values.yaml`. 

Additional configurable values:

- `image.pullPolicy`: global imagePullPolicy (IfNotPresent, Always, etc.)
- `nameOverride`, `fullnameOverride`: override generated resource names
- `config.projectDir`: path inside container where the app is mounted

For detailed options, consult `values.yaml`. 