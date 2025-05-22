# Kubernetes Configuration for Vrooli

This directory (`k8s/`) contains all the Kubernetes manifest files required to deploy the Vrooli application. We use [Kustomize](https://kustomize.io/) to manage these configurations, allowing for environment-specific customizations while keeping our base configurations DRY (Don't Repeat Yourself).

## What is Kubernetes?

Briefly, Kubernetes (often abbreviated as K8s) is an open-source system for automating deployment, scaling, and management of containerized applications. It groups containers that make up an application into logical units for easy management and discovery.

## What is Kustomize?

Kustomize is a standalone tool to customize Kubernetes objects through a kustomization file. It allows you to define a base set of Kubernetes resource configurations and then apply overlays to customize them for different environments (like staging or production) without altering the original base files.

## Directory Structure

Our Kubernetes configurations are organized as follows:

```
k8s/
├── base/                 # Common, environment-agnostic resource definitions
│   ├── server/           # Base configs for the 'server' microservice
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── jobs/             # Base configs for the 'jobs' microservice
│   │   └── deployment.yaml
│   └── ui/               # Base configs for the 'ui' microservice
│       ├── deployment.yaml
│       └── service.yaml
│
├── overlays/             # Environment-specific customizations
│   ├── staging/          # Configurations for the 'staging' environment
│   │   ├── kustomization.yaml
│   │   ├── server-replicas-patch.yaml
│   │   └── ... (other patches, ConfigMaps, Secrets for staging)
│   └── production/       # Configurations for the 'production' environment
│       ├── kustomization.yaml
│       ├── server-replicas-patch.yaml
│       └── ... (other patches, ConfigMaps, Secrets for production)
│
└── README.md             # This file
```

### `base/` Directory

*   **Purpose:** Contains the foundational Kubernetes manifest files for each microservice (`server`, `jobs`, `ui`). These files describe the desired state of each service in a generic way.
*   **Contents:**
    *   `deployment.yaml`: Defines how to run the service (e.g., Docker image, replicas, resource requests/limits, health probes). The Docker image specified here is usually a placeholder like `your-container-registry/your-app-server:latest` and will be overridden by overlays.
    *   `service.yaml`: Defines how the service is exposed within the Kubernetes cluster or externally.
*   **Key Idea:** These are the "master templates." They should not contain environment-specific values directly.

### `overlays/` Directory

*   **Purpose:** Customizes the configurations from the `base/` directory for specific target environments (e.g., `staging`, `production`).
*   **Contents (for each environment like `staging/` or `production/`):**
    *   `kustomization.yaml`: This is the control file for Kustomize within an overlay. It specifies:
        *   Which `base/` resources to use.
        *   Which patch files to apply.
        *   The correct Docker image tags for this specific environment.
        *   Common labels to apply to all resources in this environment.
        *   How to generate or reference `ConfigMaps` (for configuration data) and `Secrets` (for sensitive data) specific to this environment.
    *   **Patch Files** (e.g., `server-replicas-patch.yaml`): These are small YAML files that define *only the changes* to be applied to a base resource for this environment. For example, a patch might change the number of `replicas` for a deployment or adjust resource limits.

## How to Use These Configurations

To deploy the application to a specific environment (e.g., staging) using these Kustomize configurations, you would typically use `kubectl` with the `-k` flag:

```bash
kubectl apply -k k8s/overlays/staging
```

This command tells `kubectl` to use Kustomize to build the final set of manifests for the staging environment by applying the staging overlays to the base configurations, and then apply those manifests to your Kubernetes cluster.

To deploy to production:

```bash
kubectl apply -k k8s/overlays/production
```

## Important Placeholders & Next Steps

*   **Container Registry:** In the `kustomization.yaml` files within the `overlays/` directories (and potentially in base image definitions if not overridden), you will find image names like `your-container-registry/startupfromscratch-server:latest`. You **must** replace `your-container-registry/` with your actual container registry URL (e.g., `docker.io/yourusername`, `gcr.io/your-project-id`).
*   **Image Names & Tags:** Ensure the image names (`startupfromscratch-server`, etc.) and tags (`staging-latest`, `prod-latest`) match the images you build and push to your registry.
*   **ConfigMaps and Secrets:** The base deployments reference `ConfigMaps` (e.g., `server-config`) and `Secrets` (e.g., `server-secret`). These need to be defined, typically within the `kustomization.yaml` of each overlay (using `configMapGenerator` or `secretGenerator`) or as separate YAML files referenced by the Kustomization file. This is crucial for injecting environment-specific configurations and secrets into your application pods.
*   **Health Checks:** Review the `livenessProbe` and `readinessProbe` paths and ports in the base deployment files to ensure they match actual health check endpoints in your applications.
*   **Resource Allocation:** The CPU and memory `requests` and `limits` in the base deployments are starting points. You should monitor your application's performance in each environment and adjust these values as needed.

This Kustomize setup provides a robust and maintainable way to manage your Kubernetes deployments as the Vrooli application evolves. 