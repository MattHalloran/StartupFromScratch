#!/usr/bin/env bash
# Deploys specified build artifacts to the specified destinations.
# This script is meant to be run on the production server
set -euo pipefail
DESCRIPTION="Deploys a specific Vrooli service artifact to the target environment."

MAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ——— Default values ——— #
export ENV_FILE=""

# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/arguments.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/flow.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/locations.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/logging.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/version.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/deploy/docker.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/deploy/k8s.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/deploy/vps.sh"

# Default values set in parse_arguments
TARGET=""
SOURCE_TYPE=""
LOCATION=""
DETACHED=""
VERSION=""

# --- Argument Parsing ---

usage() {
    arg_usage "$DESCRIPTION"
    print_exit_codes
}

parse_arguments() {
    arg_reset

    arg_register_help
    # Register arguments similar to build.sh where applicable
    arg_register_sudo_mode # Assuming it might be needed by deploy functions
    arg_register_yes # For non-interactive mode
    arg_register_environment # To derive TARGET if not specified? Or just use TARGET directly. Let's stick to TARGET.

    arg_register \
        --name "source" \
        --flag "s" \
        --desc "The type of artifact/service to deploy." \
        --required "true" \
        --type "value" \
        --options "docker|k8s|vps|windows|android" # Add other valid types as needed

    arg_register \
        --name "target" \
        --flag "t" \
        --desc "Specify deployment target environment." \
        --required "true" \
        --type "value" \
        --options "staging|prod" \
        --default "prod"

    arg_register \
        --name "location" \
        --flag "l" \
        --desc "Override automatic server location detection (local|remote)." \
        --type "value" \
        --options "local|remote" \
        --default "" # Let check_location_if_not_set handle default

    arg_register \
        --name "detached" \
        --flag "x" \
        --desc "Skip teardown of reverse proxy on script exit (default: no)." \
        --type "value" \
        --options "yes|no" \
        --default "yes"

    arg_register \
        --name "version" \
        --flag "v" \
        --desc "The version of the project artifacts to deploy (defaults to version in ../../package.json)." \
        --type "value" \
        --default ""

    if is_asking_for_help "$@"; then
        usage
        exit "$EXIT_SUCCESS"
    fi

    arg_parse "$@" >/dev/null

    export SUDO_MODE=$(arg_get "sudo-mode")
    export YES=$(arg_get "yes")
    export SOURCE_TYPE=$(arg_get "source")
    export TARGET=$(arg_get "target")
    export LOCATION=$(arg_get "location")
    export DETACHED=$(arg_get "detached")
    export VERSION=$(arg_get "version")
    export ENVIRONMENT=$(arg_get "environment")

    # Set default version if not provided
    if [ -z "$VERSION" ]; then
        VERSION=$(get_project_version "../../package.json") # Assumes get_project_version can take a path
        if [ -z "$VERSION" ]; then
          error "Could not determine project version from ../../package.json. Please specify with -v."
          exit "$ERROR_CONFIGURATION"
        fi
        info "Using project version from package.json: $VERSION"
    fi
}

# --- Main Deployment Logic ---

main() {
    parse_arguments "$@"

    header "🚀 Starting deployment of '$SOURCE_TYPE' to '$TARGET' (version: $VERSION, location: $LOCATION)..."

    source "${MAIN_DIR}/setup.sh" "$@"

    # Determine artifact directory based on location and source type
    local artifact_dir
    if [[ "$LOCATION" == "local" ]]; then
        case "$SOURCE_TYPE" in
            docker)
                artifact_dir="${DEST_DIR}/artifacts/docker/${VERSION}"
                info "Expecting local Docker artifacts in: ${artifact_dir}"
                ;;
            k8s)
                artifact_dir="${DEST_DIR}/artifacts/k8s/${VERSION}"
                info "Expecting local Kubernetes artifacts in: ${artifact_dir}"
                ;;
            vps)
                # Assuming VPS deploys a general purpose bundle, e.g., 'zip' from build.sh bundles
                artifact_dir="${DEST_DIR}/bundles/zip/${VERSION}"
                info "Expecting local VPS (zip bundle) artifacts in: ${artifact_dir}"
                ;;
            windows)
                artifact_dir="${DEST_DIR}/desktop/windows/${VERSION}"
                info "Expecting local Windows Desktop artifacts in: ${artifact_dir}"
                ;;
            android)
                # This path assumes build.sh (or scripts it calls like googlePlayStore.sh)
                # will place versioned Android artifacts here for local deployment scenarios.
                # Current build.sh output for Android might need adjustments to align with this versioned path.
                artifact_dir="${DEST_DIR}/android/${VERSION}"
                info "Expecting local Android artifacts in: ${artifact_dir}"
                ;;
            *)
                error "Unsupported SOURCE_TYPE '${SOURCE_TYPE}' for local deployment artifact path. Please check configuration."
                exit "$ERROR_CONFIGURATION"
                ;;
        esac
    else # Assuming remote or other locations
        artifact_dir="${REMOTE_DIST_DIR}/${VERSION}"
        info "Expecting remote artifacts in: ${artifact_dir}"
    fi

    # Check if artifacts exist at the determined location
    if [ ! -d "$artifact_dir" ]; then
        error "Artifact directory not found: ${artifact_dir}"
        if [[ "$LOCATION" == "local" ]]; then
            error "For local deployment, ensure artifacts for SOURCE_TYPE '${SOURCE_TYPE}' (version: ${VERSION}) were correctly built and placed."
            error "This typically involves 'build.sh --dest local' or equivalent steps for the specific source type."
        else
            error "For remote deployment, ensure artifacts were built and copied using 'build.sh --dest remote' to the target server."
        fi
        exit "$ERROR_ARTIFACTS_MISSING"
    fi
    # Optionally, check for specific files needed by the source_type within artifact_dir

    if [[ "$LOCATION" == "remote" ]]; then
        setup_reverse_proxy
        if ! is_yes "$DETACHED"; then
            trap 'info "Tearing down Caddy reverse proxy..."; stop_reverse_proxy' EXIT INT TERM
        fi
    fi

    # Execute deployment based on the single source type
    info "Deploying $SOURCE_TYPE (Version: $VERSION)..."
    case "$SOURCE_TYPE" in
        docker)
            deploy_docker "$TARGET" "$artifact_dir" # Pass artifact dir if needed
            ;;
        k8s)
            deploy_k8s "$TARGET" "$artifact_dir" # Pass artifact dir if needed
            ;;
        vps)
            deploy_vps "$TARGET" "$artifact_dir" # Pass artifact dir if needed
            ;;
        windows)
            info "Deploying Windows binary (stub) from $artifact_dir"
            # Add actual deployment logic here if needed
            ;;
        android)
            info "Deploying Android package (stub) from $artifact_dir"
            # Add actual deployment logic here if needed
            ;;
        *)
            # This case should not be reached due to arg_register options
            error "Unknown source type: $SOURCE_TYPE";
            exit "$ERROR_USAGE"
            ;;
    esac

    success "✅ Deployment completed for $SOURCE_TYPE on $TARGET."
}

main "$@" 