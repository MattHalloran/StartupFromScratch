#!/usr/bin/env bash
# Builds specified artifacts for the Vrooli project, as preparation for deployment.
# This script is meant to be run on the development machine.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"
# shellcheck disable=SC1091
source "${HERE}/../build/package.sh"
# shellcheck disable=SC1091
source "${HERE}/../build/zip.sh"

# ——— Default values ——— #
# Where to load secrets/env variables from
export SECRETS_SOURCE="env"
# The environment to run the build for
ENVIRONMENT="development"
# Which bundle types to generate
BUNDLES=()
# Which container artifacts to include in the bundles
ARTIFACTS=()
# Which platform binaries to build
BINARIES=()
# Where to save bundles
DEST="local"
# Run tests before building
TEST=YES
# Run linting before building
LINT=NO
# The version of the project
VERSION=""

usage() {
    cat <<EOF
Usage: $(basename "$0") \
  [-b|--bundles <all|zip|cli>]… \
  [-a|--artifacts <docker|k8s>]… \
  [-c|--binaries <windows|mac|linux|android|ios>]… \
  [-d|--dest <local|remote>] \
  [-p|--production] \
  [-t|--test] \
  [-l|--lint] \
  [-v|--version <version>] \
  [-s|--secrets-source <env|vault>] \
  [-h|--help]

Builds specified artifacts for the Vrooli project.

Options:
  -b, --bundles    <all|zip|cli>                     Which bundle types to generate (repeatable; default: all)
  -a, --artifacts  <docker|k8s>                      Which container artifacts to include in the bundles (repeatable)
  -c, --binaries   <windows|mac|linux|android|ios>   Which platform binaries to build (repeatable)
  -d, --dest       <local|remote>                    Where to save bundles (default: local)
  -p, --production                                   Build in production mode (uses .env-prod)
  -t, --test       <Y/n>                             Run tests before building (default: true)
  -l, --lint       <Y/n>                             Run linting before building (default: false)
  -v, --version    <version>                         Set the version of the project (defaults to current version)
  -s, --secrets-source <env|vault>                   Where to load secrets/env variables from (default: env)
  -h, --help                                         Show this help message
EOF
    print_exit_codes
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--bundles)
                BUNDLES+=("$2"); shift 2;;
            -a|--artifacts)
                ARTIFACTS+=("$2"); shift 2;;
            -c|--binaries)
                BINARIES+=("$2"); shift 2;;
            -d|--dest|--destination)
                DEST="$2"; shift 2;;
            -p|--prod|--production)
                ENVIRONMENT="production"; shift;;
            -t|--test)
                TEST="$2"; shift 2;;
            -l|--lint)
                LINT="$2"; shift 2;;
            -v|--version)
                VERSION="$2"; shift 2;;
            -s|--secrets-source)
                SECRETS_SOURCE="$2"; shift 2;;
            -h|--help)
                usage; exit "$EXIT_SUCCESS";;
            *)
                echo "Unknown flag: $1"; usage; exit "$ERROR_USAGE";;
        esac
    done
}

main() {
    header "🔨 Starting build for ${ENVIRONMENT} environment..."
    parse_arguments "$@"

    # Default bundles to all if none or "all" specified
    if [ ${#BUNDLES[@]} -eq 0 ] || [[ " ${BUNDLES[*]} " =~ " all " ]]; then
        BUNDLES=("all")
    fi
    if [ -z "$VERSION" ]; then
        VERSION=$(get_project_version)
    fi

    load_secrets

    if is_yes "$TEST"; then
        header "Running tests..."
        pnpm run test
    fi
    if is_yes "$LINT"; then
        header "Running linting..."
        pnpm run lint
    fi

    set_project_version "$VERSION"

    info "Cleaning previous build artifacts..."
    clean_build

    # Process bundle types
    for b in "${BUNDLES[@]}"; do
        case "$b" in
            all)
                info "Building all bundles..."
                build_packages
                package_cli
                zip_artifacts "${ENVIRONMENT}"
                ;;
            zip)
                info "Building ZIP bundle..."
                zip_artifacts "${ENVIRONMENT}"
                ;;
            cli)
                info "Building CLI executables..."
                package_cli
                ;;
            *)
                warn "Unknown bundle type: $b"
                ;;
        esac

        if [ "$DEST" = "local" ]; then
            version=$(node -p "require('../../package.json').version")
            local dest_dir="${HERE}/../../dist/bundles/${b}/${version}"
            mkdir -p "${dest_dir}"
            cp -r "/var/tmp/${version}"/* "${dest_dir}/"
            success "Copied bundle ${b} to ${dest_dir}"
        else
            warn "Remote destination not implemented for bundle $b"
        fi
    done

    # Process container artifacts
    for a in "${ARTIFACTS[@]}"; do
        case "$a" in
            docker)
                info "Building Docker artifacts (stub)"
                # TODO: Add Docker build logic
                ;;
            k8s)
                info "Building Kubernetes artifacts (stub)"
                # TODO: Add k8s build logic
                ;;
            *)
                warn "Unknown artifact type: $a";
                ;;
        esac
        if [ "$DEST" = "local" ]; then
            warn "Local copy for artifact $a not implemented"
        else
            warn "Remote destination not implemented for artifact $a"
        fi
    done

    # Process platform binaries
    for c in "${BINARIES[@]}"; do
        case "$c" in
            windows)
                info "Building Windows binary (stub)"
                # TODO: Add Windows build logic
                ;;
            mac)
                info "Building macOS binary (stub)"
                # TODO: Add macOS build logic
                ;;
            linux)
                info "Building Linux binary (stub)"
                # TODO: Add Linux build logic
                ;;
            android)
                info "Building Android package..."
                bash "${HERE}/../build/googlePlayStore.sh"
                ;;
            ios)
                info "Building iOS package (stub)"
                # TODO: Add iOS build logic
                ;;
            *)
                warn "Unknown binary type: $c";
                ;;
        esac
        if [ "$DEST" = "local" ]; then
            warn "Local copy for binary $c not implemented"
        else
            warn "Remote destination not implemented for binary $c"
        fi
    done

    success "✅ Build process completed for ${ENVIRONMENT} environment."
}

main "$@" 