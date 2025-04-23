#!/usr/bin/env bash
set -euo pipefail

ORIGINAL_DIR="$(pwd)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${HERE}/../utils/index.sh"

# Load build scripts for clean, build, and zip functions
source "${HERE}/../build/package.sh"
source "${HERE}/../build/zip.sh"

# ——— Default values ——— #
ENVIRONMENT="development"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--production|-p] [-h|--help]

Builds all packages and bundles artifacts for the Vrooli project.

Options:
  -p, --production  Run build in production mode (uses .env-prod)
  -h, --help        Show this help message
EOF
    print_exit_codes
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--production)
                ENVIRONMENT="production"
                shift
                ;;
            -h|--help)
                usage
                exit "$EXIT_SUCCESS"
                ;;
            *)
                echo "Unknown flag: $1"
                usage
                exit "$ERROR_USAGE"
                ;;
        esac
    done
}

main() {
    header "🔨 Starting build for ${ENVIRONMENT} environment..."
    parse_arguments "$@"

    # info "Loading environment variables for ${ENVIRONMENT}..."
    # load_env_file "${ENVIRONMENT}"

    info "Cleaning previous build artifacts..."
    clean_build

    info "Building individual packages..."
    build_packages

    info "Packaging CLI executables..."
    package_cli

    info "Zipping build artifacts..."
    zip_artifacts "${ENVIRONMENT}"

    success "✅ Build process completed for ${ENVIRONMENT} environment."
}

main "$@" 