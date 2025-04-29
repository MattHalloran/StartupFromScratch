#!/usr/bin/env bash
# Deploys specified build artifacts to the specified destinations.
# This script is meant to be run on the production server
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ——— Default values ——— #
export ENV_FILE=""

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"
# shellcheck disable=SC1091
source "${HERE}/../deploy/docker.sh"
# shellcheck disable=SC1091
source "${HERE}/../deploy/k8s.sh"
# shellcheck disable=SC1091
source "${HERE}/../deploy/vps.sh"

# Default values
SOURCES=()
DEST="local"
TARGET="staging"

usage() {
    cat <<EOF
Usage: $(basename "$0") \
  [--source|-s <TYPE>]... \
  [--dest|-d <local|remote>] \
  [--target|-t <staging|prod>] \
  [-l|--location <local|remote>] \
  [-h|--help]

Deploys specified artifacts for the Vrooli project.

Options:
  -s, --source                  (local|remote) Where to find the build artifacts
  -d, --dest                    Specify artifact location: local (default) or remote
  -t, --target   <staging|prod> Specify deployment target environment
  -l, --location <local|remote> Override automatic server location detection
  -h, --help                    Show this help message
EOF
    print_exit_codes
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--source)
                SOURCES+=("$2"); shift 2;;
            -d|--dest)
                DEST="$2"; shift 2;;
            -t|--target)
                TARGET="$2"; shift 2;;
            -l|--location)
                LOCATION="$2"; shift 2;;
            staging|prod)
                TARGET="$1"; shift;;
            -h|--help)
                usage; exit "$EXIT_SUCCESS";;
            *)
                error "Unknown argument: $1"; usage; exit "$ERROR_USAGE";;
        esac
    done
}

main() {
    header "🚀 Starting deployment to $TARGET (sources: ${SOURCES[*]:-all}, dest: $DEST)..."
    parse_arguments "$@"

    # Determine env file based on target
    if [ "$TARGET" = "prod" ]; then
        ENV_FILE=".env-prod"
    else
        ENV_FILE=".env-dev"
    fi

    # Default to all sources if none specified
    if [ ${#SOURCES[@]} -eq 0 ]; then
        SOURCES=("all")
    fi

    load_secrets
    check_location_if_not_set

    if [[ "$LOCATION" == "remote" ]]; then
        header "Configuring Caddy reverse proxy for deployment..."
        setup_reverse_proxy
    fi

    for src in "${SOURCES[@]}"; do
        # Determine artifact directory for local
        if [ "$DEST" = "local" ]; then
            version=$(node -p "require('../../package.json').version")
            srcdir="${HERE}/../../dist/${src}/${version}"
            if [ ! -d "$srcdir" ]; then
                error "Artifacts not found for $src at $srcdir"
                continue
            fi
            info "Using local artifacts at $srcdir"
        else
            warn "Remote source not implemented for $src"
        fi

        case "$src" in
            all)
                for svc in docker k8s vps; do
                    info "Deploying $svc using artifacts..."
                    deploy_${svc} "$TARGET"
                done
                ;;
            docker)
                info "Deploying Docker artifacts..."
                deploy_docker "$TARGET"
                ;;
            k8s)
                info "Deploying Kubernetes artifacts..."
                deploy_k8s "$TARGET"
                ;;
            vps)
                info "Deploying VPS artifacts..."
                deploy_vps "$TARGET"
                ;;
            windows)
                info "Deploying Windows binary (stub) from $srcdir"
                ;;
            android)
                info "Deploying Android package (stub) from $srcdir"
                ;;
            *)
                warn "Unknown source type: $src";;
        esac
    done

    success "✅ Deployment completed for $TARGET."
}

main "$@" 