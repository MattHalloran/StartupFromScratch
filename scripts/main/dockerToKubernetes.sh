#!/usr/bin/env bash
set -euo pipefail

# dockerToKubernetes.sh
# ---------------------
# Converts a Docker Compose file into initial Kubernetes manifests using Kompose.
# NOTE: This script ONLY performs an initial conversion. Manual review and
# customization of the generated YAML is REQUIRED before applying to any cluster.
#
# Manual Review & Customization Checklist:
#   * Add readinessProbe and livenessProbe to each Deployment
#   * Define resource requests and limits
#   * Convert environment variables to ConfigMaps/Secrets
#   * Replace anonymous volumes with PersistentVolumeClaims
#   * Set Deployment strategies to RollingUpdate
#   * Remove or refine metadata.annotations
#   * Define Ingress or IngressRoute resources for external access
#   * Incorporate any additional cluster-specific configurations (network policies, RBAC, etc.)
#   * Validate changes with `kubectl diff -f` or `kustomize build`
#
# Usage:
#   bash scripts/main/dockerToKubernetes.sh [-f compose-file] [-o output-dir]
#
# Options:
#   -f | --file      Path to the Docker Compose file (default: docker-compose.yml)
#   -o | --output    Path to output directory for manifests (default: k8s/development)
#   -h | --help      Show this help message and exit
#
# Examples:
#   bash scripts/main/dockerToKubernetes.sh
#   bash scripts/main/dockerToKubernetes.sh -f docker-compose-prod.yml -o k8s/production

MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/locations.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/system.sh"

# Default compose file and output dir (relative to project root)
COMPOSE_FILE="docker-compose.yml"
OUTPUT_DIR="k8s/development"

function usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  -f, --file      Docker Compose file path (default: $COMPOSE_FILE)
  -o, --output    Output directory for K8s manifests (default: $OUTPUT_DIR)
  -h, --help      Display help and exit

This script uses Kompose to convert the specified Docker Compose file into
Kubernetes manifests. The first-cut YAML will live under the output directory.
Review and adjust the following areas manually:
  * Add readinessProbe and livenessProbe to each Deployment.
  * Add resource requests and limits.
  * Convert env: to ConfigMaps/Secrets as appropriate.
  * Replace anonymous volumes with PersistentVolumeClaims.
  * Set Deployment strategies (RollingUpdate).
  * Remove or refine metadata.annotations.
  * Add Ingress or IngressRoute for external access.

After conversion, you can use the following agent prompts to automate refinements:
  - "Please add a readinessProbe to <service-name>'s Deployment at containers[0]."
  - "Convert all environment variables in <service-name>.yaml to a ConfigMap."
  - "Generate a PersistentVolumeClaim for volume <volume-name> in <service-name>.yaml."
  - "Update Deployment strategy to RollingUpdate with maxSurge=1 and maxUnavailable=0."
  - "Remove all metadata.annotations from <manifest-file>."
EOF
}

# Parse arguments with validation
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--file)
      if [[ -z "${2:-}" || "$2" == -* ]]; then
        echo "Error: Missing value for $1" >&2; usage; exit 1
      fi
      COMPOSE_FILE="$2"; shift 2;;
    -o|--output)
      if [[ -z "${2:-}" || "$2" == -* ]]; then
        echo "Error: Missing value for $1" >&2; usage; exit 1
      fi
      OUTPUT_DIR="$2"; shift 2;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

# Expand leading tilde (~) in paths
COMPOSE_FILE="${COMPOSE_FILE/#\~/$HOME}"
OUTPUT_DIR="${OUTPUT_DIR/#\~/$HOME}"

# If user passed absolute paths, use them; otherwise prefix project root
if [[ "$COMPOSE_FILE" = /* ]]; then
  : # leave as-is
else
  COMPOSE_FILE="$ROOT_DIR/$COMPOSE_FILE"
fi
if [[ "$OUTPUT_DIR" = /* ]]; then
  : # leave as-is
else
  OUTPUT_DIR="$ROOT_DIR/$OUTPUT_DIR"
fi

# Normalize COMPOSE_FILE and OUTPUT_DIR with helper
COMPOSE_FILE="$(system::canonicalize "$COMPOSE_FILE")"
# Removed pre-creation canonicalization of OUTPUT_DIR to avoid errors when directory doesn't exist
# OUTPUT_DIR="$(system::canonicalize "$OUTPUT_DIR")"

# Ensure compose file exists before canonicalization
if [[ ! -e "$COMPOSE_FILE" ]]; then
  echo "Error: Docker Compose file not found at $COMPOSE_FILE" >&2
  exit 1
fi

# Ensure OUTPUT_DIR is within or equal to project root
case "$OUTPUT_DIR" in
  "$ROOT_DIR" | "$ROOT_DIR"/*) ;;
  *)
    echo "Error: OUTPUT_DIR ($OUTPUT_DIR) must be within project root ($ROOT_DIR)" >&2
    exit 1
    ;;
esac

# Prevent OUTPUT_DIR from being a non-directory file
if [[ -e "$OUTPUT_DIR" && ! -d "$OUTPUT_DIR" ]]; then
  echo "Error: OUTPUT_DIR exists and is not a directory: $OUTPUT_DIR" >&2
  exit 1
fi

# Clean old manifests
if [[ -d "$OUTPUT_DIR" ]]; then
  echo "ℹ️ Cleaning existing manifests in $OUTPUT_DIR"
  # Ensure OUTPUT_DIR is within or equal to project root to avoid catastrophic deletion
  case "$OUTPUT_DIR" in
    "$ROOT_DIR" | "$ROOT_DIR"/*) ;;
    *)
      echo "Error: OUTPUT_DIR ($OUTPUT_DIR) must be within project root ($ROOT_DIR)" >&2
      exit 1
      ;;
  esac
  # Safely remove all existing manifests (guarantee nested files and dirs are deleted)
  find "$OUTPUT_DIR" -mindepth 1 -depth -delete
fi
# Create output directory
mkdir -p "$OUTPUT_DIR"
# Canonicalize OUTPUT_DIR now that it exists (fallback if realpath/readlink not available)
OUTPUT_DIR="$(system::canonicalize "$OUTPUT_DIR" 2>/dev/null || echo "$OUTPUT_DIR")"

# Ensure kompose is installed
if ! command -v kompose >/dev/null 2>&1; then
  echo "Error: kompose is not installed. Please run 'bash scripts/main/setup.sh --target k8s-cluster' first." >&2
  exit 1
fi

# Check compose file exists
if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Error: Docker Compose file not found at $COMPOSE_FILE" >&2
  exit 1
fi

echo "🔧 Converting $COMPOSE_FILE to Kubernetes manifests in $OUTPUT_DIR..."
kompose convert -f "$COMPOSE_FILE" -o "$OUTPUT_DIR"

echo "✅ Conversion complete!"
echo ""
echo "Next Steps:"
echo "1) Review the generated YAML in $OUTPUT_DIR."
echo "2) Apply the manifests: kubectl apply -f $OUTPUT_DIR" 

echo "3) Inspect pod status: kubectl get pods"
echo ""
echo "Suggested agent prompts for manifest refinement:"
echo "  - \"Add livenessProbe to the container in deployments/<service>.yaml.\""
echo "  - \"Add resource requests and limits to <service>.yaml.\""
echo "  - \"Generate and use a ConfigMap for environment variables in <service>.yaml.\""
echo "  - \"Create PersistentVolumeClaim for volume in <service>.yaml.\""
echo "  - \"Remove metadata.annotations from all YAML files in $OUTPUT_DIR.\"" 