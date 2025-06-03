# Setting Up a Kubernetes Cluster for Vrooli

This guide will walk you through setting up a Kubernetes cluster, with a focus on DigitalOcean Kubernetes (DOKS), and deploying the Vrooli application to it using the provided Helm chart and deployment scripts.

## 1. Why Kubernetes for Vrooli?

Kubernetes (K8s) is a powerful open-source system for automating the deployment, scaling, and management of containerized applications like Vrooli. It offers:
*   **Scalability:** Easily scale your application components (UI, server, jobs) up or down based on demand.
*   **Resilience:** Kubernetes can automatically restart failed containers and reschedule them on healthy nodes.
*   **Service Discovery & Load Balancing:** Simplifies how different parts of Vrooli discover and communicate with each other, and how traffic is distributed.
*   **Automated Rollouts & Rollbacks:** Provides mechanisms for deploying new versions of Vrooli with zero downtime and rolling back if issues occur.
*   **Efficient Resource Utilization:** Optimizes the use of your underlying server resources.

## 2. Choosing a Kubernetes Provider

While you can set up Kubernetes on your own servers, managed Kubernetes services from cloud providers significantly simplify cluster creation and maintenance.

### Recommended: DigitalOcean Kubernetes (DOKS)

DigitalOcean Kubernetes (DOKS) offers a straightforward and cost-effective way to get a Kubernetes cluster up and running. This guide will primarily focus on DOKS.

### Alternatives

Other popular managed Kubernetes services include:
*   **Amazon Web Services (AWS):** Amazon Elastic Kubernetes Service (EKS)
*   **Google Cloud Platform (GCP):** Google Kubernetes Engine (GKE)
*   **Microsoft Azure:** Azure Kubernetes Service (AKS)
*   **Linode:** Linode Kubernetes Engine (LKE)

The general principles of setting up a cluster and deploying Vrooli will be similar across these providers, mainly differing in their specific UI/CLI for cluster creation and `kubeconfig` retrieval.

## 3. Setting up with DigitalOcean Kubernetes (DOKS)

### Prerequisites
*   A DigitalOcean account. If you don't have one, sign up at [cloud.digitalocean.com](https://cloud.digitalocean.com/).

### Steps to Create a DOKS Cluster

1.  **Navigate to Kubernetes:**
    *   Log in to your DigitalOcean account.
    *   In the left-hand navigation pane, click "Kubernetes."

2.  **Create a Cluster:**
    *   Click the "Create Cluster" button.
    *   **Select a Kubernetes version:** Choose a recent, stable version.
    *   **Choose a datacenter region:** Select a region geographically close to you or your users.
    *   **VPC Network:** You can usually leave this as the default VPC for the chosen region.
    *   **Node Pool(s):** This defines the worker machines for your cluster.
        *   **Name:** Give your node pool a descriptive name (e.g., `vrooli-workers`).
        *   **Node plan:** Select the size of the Droplets (VMs) for your worker nodes. For a small to medium Vrooli setup, starting with "Basic Nodes" and a plan like "2 vCPUs / 4 GB RAM" per node might be sufficient. You can adjust this later.
        *   **Number of nodes:** Start with at least 2 or 3 nodes for basic redundancy and capacity.
    *   **Cluster Name:** Give your cluster a unique and descriptive name (e.g., `vrooli-staging-cluster` or `vrooli-prod-cluster`).
    *   **Tags (Optional):** Add any tags you find useful for organization.
    *   Click "Create Cluster." Provisioning will take a few minutes.

3.  **Download Kubeconfig:**
    *   Once the cluster is provisioned (status shows as "Running"), click on your cluster's name.
    *   Scroll down to the "Kubeconfig" section.
    *   Click the "Download Config File" button. This will download a YAML file (e.g., `vrooli-staging-cluster-kubeconfig.yaml`). **Treat this file as sensitive, as it provides administrative access to your cluster.**

4.  **Configure `kubectl` to Use Your DOKS Cluster:**
    *   **Install `kubectl`:** If you don't have it, install the Kubernetes command-line tool following the official [Kubernetes documentation](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/).
    *   **Install `helm`:** You'll also need Helm v3. Follow the [Helm installation guide](https://helm.sh/docs/intro/install/).
    *   **Set KUBECONFIG Environment Variable (Recommended for simplicity):**
        Open your terminal and set the `KUBECONFIG` environment variable to point to your downloaded config file:
        ```bash
        export KUBECONFIG=/path/to/your/downloaded/vrooli-cluster-kubeconfig.yaml
        ```
        To make this permanent for your current session or future sessions, add this line to your shell's profile file (e.g., `~/.bashrc`, `~/.zshrc`) and then source it (e.g., `source ~/.bashrc`).
    *   **Alternatively (Merging into default kubeconfig):** You can merge this new configuration into your existing `~/.kube/config` file. `kubectl` uses this file by default if `KUBECONFIG` is not set.
        ```bash
        # Backup your existing config
        cp ~/.kube/config ~/.kube/config.backup

        # Merge the new config (ensure KUBECONFIG points to your new file for this command)
        KUBECONFIG=~/.kube/config:/path/to/your/downloaded/vrooli-cluster-kubeconfig.yaml kubectl config view --flatten > ~/.kube/config.merged
        mv ~/.kube/config.merged ~/.kube/config

        # Set context to your new cluster
        kubectl config use-context <your-cluster-context-name> 
        # (You can find the context name with `kubectl config get-contexts`)
        ```

5.  **Verify Cluster Access:**
    Open a terminal and run:
    ```bash
    kubectl get nodes
    ```
    You should see a list of the worker nodes in your DOKS cluster with a "Ready" status.
    ```bash
    kubectl cluster-info
    ```
    This will show you the Kubernetes control plane and CoreDNS addresses.

## 4. Brief Overview of Other Providers

*   **AWS EKS, GCP GKE, Azure AKS:** These services have comprehensive documentation. The process generally involves:
    1.  Using their respective CLIs (`eksctl`, `gcloud`, `az`) or web consoles to provision a cluster.
    2.  Configuring node pools (instance types, counts).
    3.  Authenticating your local `kubectl` CLI with the new cluster (they usually provide commands to update your `kubeconfig`).

## 5. Prerequisites for Deploying Vrooli to Your Cluster

Before deploying Vrooli, ensure the following are set up:

### a. Container Registry (Docker Hub)
Your `scripts/main/build.sh` script already pushes tagged Docker images for Vrooli services (ui, server, jobs) to Docker Hub. Your Kubernetes cluster needs to be able to pull these images. By default, Kubernetes can pull from public Docker Hub repositories. If your images are private, you'll need to configure an `imagePullSecret` in your Kubernetes cluster and reference it in your Helm chart's `values.yaml` or service definitions.

### b. Secrets Management: HashiCorp Vault & Vault Secrets Operator (VSO)
Vrooli is designed to use HashiCorp Vault for secrets management, integrated into Kubernetes via the Vault Secrets Operator (VSO).
*   **Set up Vault:** You need a running HashiCorp Vault instance that is accessible from your Kubernetes cluster. This could be a Vault cluster running within Kubernetes itself (often set up via its own Helm chart) or an external Vault instance.
*   **Install VSO:** The Vault Secrets Operator must be installed in your Kubernetes cluster.
*   **Populate Vault & Configure VSO in Helm:**
    *   Ensure your Vault instance is populated with the necessary secrets for Vrooli (PostgreSQL credentials, Redis credentials, application API keys, etc.) at the paths defined in your Helm chart's `values.yaml` (under the `vso.secrets` section).
    *   Your Helm chart (`k8s/chart/values.yaml` and environment-specific overrides like `values-prod.yaml`) needs to be correctly configured to enable and connect to VSO.
    *   **Refer extensively to your project's `k8s/README.md` file.** It contains detailed information and configurations for setting up VSO, `VaultAuth`, `VaultConnection`, and `VaultSecret` resources.

### c. Persistent Storage
PostgreSQL (managed by PGO) and Redis (managed by Spotahome Operator) require persistent storage. Configuration for this is handled within their respective sections (`pgoPostgresql` and `spotahomeRedis`) in the Helm chart's `values.yaml`.
*   Managed Kubernetes services like DOKS provide default `StorageClass` resources (e.g., using DigitalOcean Block Storage). The operators will typically use these defaults if no specific `storageClassName` is provided in the `values.yaml` for their storage requests.
*   **PostgreSQL Backups (pgBackRest with PGO):**
    *   The default configuration in `values.yaml` for PGO's pgBackRest uses a PersistentVolumeClaim (PVC) for storing backups. This is suitable for development and testing.
    *   **For production environments, it is critical to configure pgBackRest to use external, durable object storage like AWS S3, Google Cloud Storage (GCS), or Azure Blob Storage.** This ensures backup data is safe from cluster-level failures.
    *   To do this, you would need to:
        1.  Set up an S3 bucket (or equivalent) and create appropriate access credentials (e.g., IAM user/role with necessary S3 permissions).
        2.  Store these credentials securely, for example, in HashiCorp Vault, and configure VSO to sync them as a Kubernetes Secret.
        3.  Modify the `pgoPostgresql.backups.pgBackRest.repos` section in your `values-prod.yaml` to define an S3 repository type, referencing the bucket name, region, endpoint (if not AWS S3 standard), and the Kubernetes Secret containing the credentials. Refer to the [Crunchy Data PGO documentation](https://access.crunchydata.com/documentation/postgres-operator/latest/tutorial/backups/) for detailed S3 configuration examples.
*   **Redis Persistence:**
    *   The Spotahome Redis Operator also uses PVCs for Redis data. Ensure the `spotahomeRedis.redis.storage.keepAfterDeletion` is set to `true` in `values-prod.yaml` to prevent data loss if the `RedisFailover` custom resource is accidentally deleted.
*   If you encounter issues with PVC binding, check available storage classes (`kubectl get storageclass`) and ensure your `values.yaml` (or environment-specific overrides) correctly specify a `storageClassName` if the default is not suitable.

### d. Ingress Controller (for External Access)
To expose Vrooli services (especially the UI and server API) to the internet via HTTP/HTTPS, you'll typically use an Ingress controller.
*   **DOKS Ingress:** DigitalOcean offers an integrated Nginx Ingress controller that you can enable when creating your cluster or add later. This is often the easiest way.
*   **Manual Installation:** Alternatively, you can install an Ingress controller like Nginx or Traefik using their Helm charts.
*   **Helm Chart Configuration:**
    *   Your Vrooli Helm chart (`k8s/chart/templates/ingress.yaml`) defines Ingress resources.
    *   Ensure the `ingress.enabled` flag is set to `true` in your environment-specific `values.yaml` (e.g., `values-prod.yaml`).
    *   Configure `ingress.hosts` and `ingress.tls` (for HTTPS) as needed. You might need to set the `ingress.className` depending on the Ingress controller you use.

## 6. Deploying Vrooli to Your Cluster

Once your Kubernetes cluster is accessible via `kubectl` from your deployment environment and the prerequisites are met:

1.  **Ensure Artifacts are Available:**
    The `scripts/main/build.sh` script should have been run, producing an `artifacts.zip.gz` file. This file needs to be present in the `bundles_dir` (e.g., `${var_DEST_DIR}/${VERSION}/bundles/`) expected by `deploy.sh`. If `build.sh` was run on a different machine, transfer this `artifacts.zip.gz` to your deployment environment.

2.  **Run the Deployment Script:**
    Navigate to the root of your Vrooli project directory in your terminal. Execute the deployment script:
    ```bash
    # Ensure VERSION and ENVIRONMENT are set appropriately
    # For example, deploying version 0.2.0 to a 'production' environment/namespace
    export VERSION="0.2.0" 
    export ENVIRONMENT="production" # This will be the Kubernetes namespace

    bash scripts/main/deploy.sh -s k8s -e "$ENVIRONMENT" -v "$VERSION"
    ```
    *   `-s k8s`: Specifies a Kubernetes deployment.
    *   `-e "$ENVIRONMENT"`: Sets the target environment (e.g., `staging`, `production`). This will be used as the Kubernetes namespace and to select the appropriate Helm values file (e.g., `k8s/chart/values-production.yaml` would be referenced by the logic within `deploy::deploy_k8s` if it were to use external values files in addition to the packaged ones. Currently, it primarily uses this for namespace and release naming, and the packaged chart contains its own `values.yaml`).
    *   `-v "$VERSION"`: Specifies the version of Vrooli to deploy. This should match the version used during the build and for Docker image tags.

    The script will:
    *   Run `setup.sh` (which includes Docker setup, etc., though less critical if deploying to an existing K8s cluster).
    *   Unpack the build artifacts (including the versioned Helm chart `.tgz` package).
    *   Call `deploy::deploy_k8s`, which then uses `helm upgrade --install` to deploy your Vrooli application to the specified namespace in your DOKS cluster, using the packaged chart.

## 7. Verifying the Deployment

After the `deploy.sh` script completes, use `kubectl` to check the status of your Vrooli deployment:

*   **Check all resources in the namespace:**
    ```bash
    kubectl get all -n "$ENVIRONMENT" 
    # (e.g., kubectl get all -n production)
    ```
*   **List Pods:**
    ```bash
    kubectl get pods -n "$ENVIRONMENT" -o wide
    ```
    Look for Pods for `vrooli-ui`, `vrooli-server`, `vrooli-jobs`, `vrooli-postgresql`, `vrooli-redis` (or however your release names them, typically `vrooli-<environment>-<service-name>`). They should be in a `Running` or `Completed` state.
*   **View Logs:**
    If a Pod is not running correctly (e.g., `CrashLoopBackOff`, `ImagePullBackOff`), check its logs:
    ```bash
    kubectl logs <pod-name> -n "$ENVIRONMENT"
    # To follow logs:
    kubectl logs -f <pod-name> -n "$ENVIRONMENT"
    # If a pod has multiple containers:
    kubectl logs <pod-name> -c <container-name> -n "$ENVIRONMENT"
    ```
*   **Check Services:**
    ```bash
    kubectl get services -n "$ENVIRONMENT"
    ```
    This will show internal ClusterIPs and any external IPs if you're using LoadBalancer services (less common if using Ingress).
*   **Check Ingresses (if enabled):**
    ```bash
    kubectl get ingress -n "$ENVIRONMENT"
    ```
    This should show the hostnames and IP address for accessing your application externally. You might need to configure DNS to point your desired domain to the Ingress controller's external IP.

*   **Accessing Services for Testing:**
    *   **Port Forwarding (for internal services or direct pod access):**
        ```bash
        # Example: Access the UI service locally on port 8080
        kubectl port-forward service/vrooli-"$ENVIRONMENT"-ui 8080:3000 -n "$ENVIRONMENT" 
        # (Assuming service is named vrooli-<environment>-ui and listens on port 3000)
        # Then open http://localhost:8080 in your browser.
        ```
    *   **Via Ingress:** If Ingress is set up with a hostname, access Vrooli via `http://<your-configured-host>` or `https://<your-configured-host>`.

## 8. Basic Troubleshooting

*   **`ImagePullBackOff`:**
    *   The Kubernetes node cannot pull the Docker image.
    *   Causes: Incorrect image name/tag in `values.yaml` (or `--set` overrides), image doesn't exist in the registry, registry requires authentication and `imagePullSecrets` are missing/incorrect.
    *   Check `kubectl describe pod <pod-name> -n "$ENVIRONMENT"` for details.
*   **`CrashLoopBackOff`:**
    *   The application inside the container is starting and then crashing repeatedly.
    *   Check logs: `kubectl logs <pod-name> -n "$ENVIRONMENT"`.
    *   Common causes: Application misconfiguration (missing environment variables, wrong database connection strings), bugs in the application, insufficient resources (CPU/memory).
*   **Pending Pods:**
    *   Pods are stuck in a `Pending` state.
    *   Causes: Insufficient cluster resources (CPU, memory), PVCs cannot bind (storage issues), taints/tolerations issues.
    *   Check `kubectl describe pod <pod-name> -n "$ENVIRONMENT"` for events.
*   **VSO Secret Sync Issues:**
    *   If pods dependent on VSO-synced secrets are failing, check the logs of the Vault Secrets Operator pods in its namespace (often `vault-secrets-operator` or `kube-system`).
    *   Check the status of `VaultSecret` custom resources: `kubectl get vaultsecret -n "$ENVIRONMENT"`.
    *   Ensure Vault is reachable and `VaultAuth`/`VaultConnection` are correctly configured.
*   **Helm Failures:**
    *   If `helm upgrade --install` fails, `deploy::deploy_k8s.sh` attempts to show `helm status` and `helm history`. Review this output.
    *   Common Helm issues: Templating errors in the chart, incorrect values in `values.yaml`, CRDs not yet available in the cluster.

This guide should provide a solid starting point for deploying Vrooli to a managed Kubernetes cluster. Remember to consult the specific documentation for your chosen cloud provider and the Vrooli project's `k8s/README.md` for more detailed configuration options.

## 9. Future Steps: Global Distribution with GSLB

As Vrooli grows and requires a global presence with higher availability and lower latency for users in different parts of the world, you'll need to consider solutions that operate above individual Kubernetes clusters. Single Kubernetes clusters, even highly available ones within a region, are typically bound to that specific geographic location.

**Global Server Load Balancing (GSLB)** is the technology that addresses this. GSLB solutions distribute user traffic across multiple, geographically dispersed application endpoints, which in this case would be your Vrooli deployments running in Kubernetes clusters in different regions (e.g., one DOKS cluster in North America, another in Europe, and one in Asia).

### Benefits of GSLB for Vrooli:

*   **Improved Availability & Disaster Recovery:** If one regional cluster becomes unavailable (e.g., due to a datacenter outage), GSLB can automatically redirect traffic to healthy clusters in other regions, minimizing downtime.
*   **Lower Latency:** Users can be directed to the cluster geographically closest to them, reducing request times and improving their experience.
*   **Increased Capacity:** Distributes the load across multiple clusters, allowing Vrooli to handle a larger number of concurrent users.

### k8gb: A Kubernetes-Native GSLB Solution

One promising open-source solution for implementing GSLB in a Kubernetes environment is **k8gb** ([http://www.k8gb.io/](http://www.k8gb.io/)).

Key features of k8gb relevant to Vrooli could include:

*   **DNS-Based Load Balancing:** It uses the robust and widely adopted DNS protocol to direct traffic.
*   **Cloud-Native:** Designed to work natively with Kubernetes. Configuration is managed via a `Gslb` Custom Resource Definition (CRD) within your clusters.
*   **Multiple Strategies:** Supports strategies like:
    *   **Failover:** Designate a primary region and one or more backup regions. Traffic automatically fails over if the primary becomes unhealthy.
    *   **GeoIP:** Route users to the nearest cluster based on their IP address (often requires integration with a DNS provider that supports this).
*   **Health Checks:** Utilizes Kubernetes Liveness and Readiness probes to determine the health of your Vrooli application in each cluster, making informed load balancing decisions.
*   **No Single Point of Failure:** k8gb is designed to be decentralized, avoiding a single management cluster that could bring down the GSLB capabilities.

### How k8gb Might Work with Vrooli on DOKS:

1.  **Multiple DOKS Clusters:** You would set up Vrooli on DOKS clusters in different DigitalOcean regions (e.g., `NYC1`, `AMS3`, `SGP1`).
2.  **k8gb Installation:** Install k8gb in each of these DOKS clusters.
3.  **DNS Integration:** k8gb needs to integrate with an external DNS provider (e.g., DigitalOcean DNS, AWS Route53, Cloudflare, etc.) that it can control to update DNS records based on cluster health and the chosen GSLB strategy.
4.  **Gslb CRD Configuration:** You would define `Gslb` resources in your clusters. This CRD would specify:
    *   The Vrooli Ingress or Service to be globally load-balanced.
    *   The GSLB strategy (e.g., failover, round-robin between geo-tagged clusters).
    *   Geo tags for your clusters (e.g., `us-east`, `eu-central`).
    *   Details for your DNS provider integration.

When a user tries to access Vrooli, their DNS query would be resolved by the k8gb-managed DNS records, directing them to the most appropriate regional DOKS cluster running Vrooli based on the configured strategy and real-time health checks.

### Considerations for Implementing GSLB:

*   **Data Replication and Synchronization:** If Vrooli uses stateful components like PostgreSQL, you'll need a strategy for replicating or synchronizing data across regions. This is a complex topic on its own and critical for a truly globally distributed application. Solutions might involve asynchronous replication, multi-master databases, or application-level logic for data sharding/federation.
*   **DNS Propagation Times:** DNS changes can take time to propagate globally, which can affect how quickly failover occurs.
*   **Complexity:** Managing a multi-cluster, globally distributed application adds operational complexity compared to a single-cluster setup.
*   **Cost:** Running multiple clusters and potentially more sophisticated database replication setups will incur higher costs.

Implementing GSLB with k8gb would be a significant architectural step, suitable when Vrooli needs to scale beyond a single region. It offers a powerful way to build a highly resilient and performant global application on Kubernetes. 