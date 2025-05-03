#!/usr/bin/env bash
# Builds specified artifacts for the Vrooli project, as preparation for deployment.
# This script is meant to be run on the development machine.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

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

parse_arguments() {
    arg_reset

    arg_register_help
    arg_register_secrets_source
    arg_register_sudo_mode
    arg_register_yes
    arg_register_environment

    arg_register \
        --name "bundles" \
        --flag "b" \
        --desc "Which bundle types to generate, separated by commas without spaces (default: zip)" \
        --type "value" \
        --options "all|zip|cli" \
        --default "all"
    
    arg_register \
        --name "artifacts" \
        --flag "a" \
        --desc "Which container artifacts to include in the bundles, separated by commas without spaces (default: docker)" \
        --type "value" \
        --options "all|docker|k8s" \
        --default "all"

    arg_register \
        --name "binaries" \
        --flag "c" \
        --desc "Which platform binaries to build, separated by commas without spaces (default: none)" \
        --type "value" \
        --options "all|windows|mac|linux|android|ios" \
        --default "all"

    arg_register \
        --name "dest" \
        --flag "d" \
        --desc "Where to save bundles (default: local)" \
        --type "value" \
        --options "local|remote" \
        --default "local"

    arg_register \
        --name "test" \
        --flag "t" \
        --desc "Run tests before building (default: true)" \
        --type "value" \
        --options "yes|no" \
        --default "yes"
    
    arg_register \
        --name "lint" \
        --flag "l" \
        --desc "Run linting before building (default: true)" \
        --type "value" \
        --options "yes|no" \
        --default "no"
    
    arg_register \
        --name "version" \
        --flag "v" \
        --desc "The version of the project (defaults to current version set in package.json)" \
        --type "value" \
        --default ""

    if is_asking_for_help "$@"; then
        arg_usage "$DESCRIPTION"
        print_exit_codes
        exit 0
    fi

    arg_parse "$@" >/dev/null
    
    export SECRETS_SOURCE=$(arg_get "secrets-source")
    export SUDO_MODE=$(arg_get "sudo-mode")
    export YES=$(arg_get "yes")
    export ENVIRONMENT=$(arg_get "environment")
    export BUNDLES=$(arg_get "bundles")
    export ARTIFACTS=$(arg_get "artifacts")
    export BINARIES=$(arg_get "binaries")
    export DEST=$(arg_get "dest")
    export TEST=$(arg_get "test")
    export LINT=$(arg_get "lint")
    export VERSION=$(arg_get "version")

    if [ -z "$BUNDLES" ]; then
        BUNDLES="zip"
    fi
    if [ -z "$ARTIFACTS" ]; then
        ARTIFACTS="docker"
    fi
    if [ -z "$BINARIES" ]; then
        BINARIES=""
    fi
    if [ -z "$DEST" ]; then
        DEST="local"
    fi
    if [ -z "$TEST" ]; then
        TEST="yes"
    fi
    if [ -z "$LINT" ]; then
        LINT="yes"
    fi
    if [ -z "$VERSION" ]; then
        VERSION=$(get_project_version)
    fi
}

main() {
    parse_arguments "$@"
    header "🔨 Starting build for ${ENVIRONMENT} environment..."

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