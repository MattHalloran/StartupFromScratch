#!/usr/bin/env bash
# Builds specified artifacts for the Vrooli project, as preparation for deployment.
# This script is meant to be run on the development machine.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# ——— Default values ——— #
# Where to load secrets/env variables from
SECRETS_SOURCE="env"
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
# What to do when encountering sudo commands without elevated privileges
SUDO_MODE="error"

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"
# shellcheck disable=SC1091
source "${HERE}/../build/index.sh"
# shellcheck disable=SC1091
source "${HERE}/../build/artifacts/index.sh"
# shellcheck disable=SC1091
source "${HERE}/../build/binaries/index.sh"
# shellcheck disable=SC1091
source "${HERE}/../build/bundles/index.sh"

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
  [-m|--sudo-mode <error|skip>] \
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
  -m, --sudo-mode  <error|skip>                      What to do when encountering sudo commands without elevated privileges (default: error)
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
            -m|--sudo-mode)
                SUDO_MODE="$2"; shift 2;;
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

    # Export variables AFTER parsing arguments so they reflect user input
    export SECRETS_SOURCE
    export SUDO_MODE

    # Default bundles to all if none or "all" specified
    if [ ${#BUNDLES[@]} -eq 0 ] || [[ " ${BUNDLES[*]} " =~ " all " ]]; then
        BUNDLES=("all")
    fi
    if [ -z "$VERSION" ]; then
        VERSION=$(get_project_version)
    fi

    load_secrets

    info "Cleaning previous build artifacts..."
    clean_build

    # Need to build packages first for tests to run correctly
    build_packages
    verify_build

    if is_yes "$TEST"; then
        header "Running tests..."
        # Run tests without rebuilding packages
        pnpm run test:shell
        pnpm run test:unit
        pnpm run test:run
    fi
    if is_yes "$LINT"; then
        header "Running linting..."
        pnpm run lint
    fi

    set_project_version "$VERSION"

    # Determine if any binary/desktop builds are requested
    local build_desktop=NO
    if [ ${#BINARIES[@]} -gt 0 ]; then
      build_desktop=YES
    fi

    # Build Electron main/preload scripts if building desktop app
    if is_yes "$build_desktop"; then
      header "Building Electron scripts..."
      # Ensure a tsconfig for electron exists
      # Adjust the output dir (-outDir) if needed
      npx tsc --project platforms/desktop/tsconfig.json --outDir dist/desktop || {
        error "Failed to build Electron scripts. Ensure platforms/desktop/tsconfig.json is configured."; exit "$ERROR_BUILD_FAILED";
      }
      # Rename output to .cjs to explicitly mark as CommonJS
      mv dist/desktop/main.js dist/desktop/main.cjs || { error "Failed to rename main.js to main.cjs"; exit "$ERROR_BUILD_FAILED"; }
      mv dist/desktop/preload.js dist/desktop/preload.cjs || { error "Failed to rename preload.js to preload.cjs"; exit "$ERROR_BUILD_FAILED"; }
      success "Electron scripts built and renamed to .cjs."
    fi

    # Process bundle types
    for b in "${BUNDLES[@]}"; do
        case "$b" in
            all)
                info "Building all bundles..."
                package_cli
                zip_artifacts "${ENVIRONMENT}" "${VERSION}"
                ;;
            zip)
                info "Building ZIP bundle..."
                zip_artifacts "${ENVIRONMENT}" "${VERSION}"
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
            local dest_dir="${HERE}/../../dist/bundles/${b}/${VERSION}"
            mkdir -p "${dest_dir}"
            local source_dir="/var/tmp/${VERSION}"
            if [ -d "${source_dir}" ]; then
              cp -r "${source_dir}"/* "${dest_dir}/"
              success "Copied bundle ${b} version ${VERSION} to ${dest_dir}"
            else
              warn "Source directory ${source_dir} not found for bundle ${b}. Skipping copy."
            fi
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

    # Process platform binaries (now Desktop Apps)
    for c in "${BINARIES[@]}"; do
        local target_platform=""
        case "$c" in
            windows)
                info "Building Windows Desktop App (Electron)..."
                # Ensure Wine is installed using the robust method
                install_wine_robustly
                target_platform="--win --x64"
                ;;
            mac)
                info "Building macOS Desktop App (Electron)..."
                target_platform="--mac --x64"
                ;;
            linux)
                info "Building Linux Desktop App (Electron)..."
                target_platform="--linux --x64"
                ;;
            # android/ios are likely mobile builds, not desktop - keeping stubs
            android)
                info "Building Android package..."
                bash "${HERE}/../build/googlePlayStore.sh"
                continue # Skip electron-builder for android
                ;;
            ios)
                info "Building iOS package (stub)"
                # TODO: Add iOS build logic
                continue # Skip electron-builder for ios
                ;;
            *)
                warn "Unknown binary/desktop type: $c";
                continue
                ;;
        esac

        if [ -n "$target_platform" ]; then
            info "Running electron-builder for $c (this may take several minutes)..."
            # Pass platform and arch flags separately
            npx electron-builder $target_platform || {
              error "Electron build failed for $c."; exit "$ERROR_BUILD_FAILED";
            }
            success "Electron build completed for $c. Output in dist/desktop/"

            # Copying logic (optional, adjust as needed)
            if [ "$DEST" = "local" ]; then
              local dest_dir="${HERE}/../../dist/desktop/${c}/${VERSION}"
              local source_dir="${HERE}/../../dist/desktop"
              mkdir -p "${dest_dir}"
              # Copy specific installer/package file(s)
              # This is an example, glob patterns might need adjustment
              find "${source_dir}" -maxdepth 1 -name "Vrooli*.$([ "$c" == "windows" ] && echo "exe" || ([ "$c" == "mac" ] && echo "dmg" || echo "AppImage"))" -exec cp {} "${dest_dir}/" \;
              success "Copied $c desktop artifact to ${dest_dir}"
            else
                warn "Remote destination not implemented for desktop app $c"
            fi
        fi

    done

    success "✅ Build process completed for ${ENVIRONMENT} environment."
}

main "$@" 