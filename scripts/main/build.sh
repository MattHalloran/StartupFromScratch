#!/usr/bin/env bash
set -euo pipefail
DESCRIPTION="Builds specified artifacts for the Vrooli project, as preparation for deployment."

MAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/args.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/docker.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/env.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/flow.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/keyless_ssh.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/locations.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/log.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/system.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/version.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/zip.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/build/index.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/build/binaries/index.sh"

build::parse_arguments() {
    args::reset

    args::register_help
    args::register_sudo_mode
    args::register_yes
    args::register_location
    args::register_environment

    args::register \
        --name "bundles" \
        --flag "b" \
        --desc "Which bundle types to generate, separated by commas without spaces (default: zip)" \
        --type "value" \
        --options "all|zip|cli" \
        --default "all"
    
    args::register \
        --name "artifacts" \
        --flag "a" \
        --desc "Which container artifacts to include in the bundles, separated by commas without spaces (default: docker)" \
        --type "value" \
        --options "all|docker|k8s" \
        --default "all"

    args::register \
        --name "binaries" \
        --flag "c" \
        --desc "Which platform binaries to build, separated by commas without spaces (default: none)" \
        --type "value" \
        --options "all|windows|mac|linux|android|ios" \
        --default ""

    args::register \
        --name "dest" \
        --flag "d" \
        --desc "Where to save bundles (default: local)" \
        --type "value" \
        --options "local|remote" \
        --default "local"

    args::register \
        --name "test" \
        --flag "t" \
        --desc "Run tests before building (default: true)" \
        --type "value" \
        --options "yes|no" \
        --default "yes"
    
    args::register \
        --name "lint" \
        --flag "q" \
        --desc "Run linting before building (default: true)" \
        --type "value" \
        --options "yes|no" \
        --default "no"
    
    args::register \
        --name "version" \
        --flag "v" \
        --desc "The version of the project (defaults to current version set in package.json)" \
        --type "value" \
        --default ""

    if args::is_asking_for_help "$@"; then
        args::usage "$DESCRIPTION"
        exit_codes::print
        exit 0
    fi

    args::parse "$@" >/dev/null
    
    export SUDO_MODE=$(args::get "sudo-mode")
    export YES=$(args::get "yes")
    export LOCATION=$(args::get "location")
    export ENVIRONMENT=$(args::get "environment")
    # Read comma-separated strings into temp variables
    local bundles_str=$(args::get "bundles")
    local artifacts_str=$(args::get "artifacts")
    local binaries_str=$(args::get "binaries")
    export DEST=$(args::get "dest")
    export TEST=$(args::get "test")
    export LINT=$(args::get "lint")
    export VERSION=$(args::get "version")

    # Split the strings into arrays
    IFS=',' read -r -a BUNDLES <<< "$bundles_str"
    IFS=',' read -r -a ARTIFACTS <<< "$artifacts_str"
    IFS=',' read -r -a BINARIES <<< "$binaries_str"

    # Treat explicit 'none' values (or default empty for binaries) as empty lists
    if [ "$bundles_str" = "none" ]; then
        BUNDLES=()
    fi
    if [ "$artifacts_str" = "none" ]; then
        ARTIFACTS=()
    fi
    if [ "$binaries_str" = "none" ]; then
        BINARIES=()
    fi
    # Treat explicit 'all' values as full arrays
    if [ "$bundles_str" = "all" ]; then
        BUNDLES=("zip" "cli")
    fi
    if [ "$artifacts_str" = "all" ]; then
        ARTIFACTS=("docker" "k8s")
    fi
    if [ "$binaries_str" = "all" ]; then
        BINARIES=("windows" "mac" "linux" "android" "ios")
    fi
    # Treat missing values as their default values
    if [ -z "$bundles_str" ]; then
        BUNDLES=("zip")
    fi
    if [ -z "$artifacts_str" ]; then
        ARTIFACTS=("docker")
    fi
    if [ -z "$binaries_str" ]; then
        BINARIES=()
    fi

    # Handle default destination, test, lint
    if [ -z "$DEST" ]; then
        DEST="local"
    fi
    if [ -z "$TEST" ]; then
        TEST="yes"
    fi
    if [ -z "$LINT" ]; then
        LINT="no" # Default changed to 'no' based on arg definition
    fi
    if [ -z "$VERSION" ]; then
        VERSION=$(get_project_version)
    fi
}

build::main() {
    build::parse_arguments "$@"
    log::header "🔨 Starting build for ${ENVIRONMENT} environment..."

    source "${MAIN_DIR}/setup.sh" "$@"

    log::info "Cleaning previous build artifacts..."
    clean_build

    # Need to build packages first for tests to run correctly
    build_packages
    verify_build

    if flow::is_yes "$TEST"; then
        log::header "Running tests..."
        # Run tests without rebuilding packages
        pnpm run test:shell
        pnpm run test:unit
        pnpm run test:run
    fi
    if flow::is_yes "$LINT"; then
        log::header "Running linting..."
        pnpm run lint
    fi

    set_project_version "$VERSION"

    # Determine if any binary/desktop builds are requested
    local build_desktop="NO"
    # Check array length correctly
    if [ ${#BINARIES[@]} -gt 0 ]; then
      build_desktop="YES"
    fi

    # Build Electron main/preload scripts if building desktop app
    if flow::is_yes "$build_desktop"; then
      log::header "Building Electron scripts..."
      # Ensure a tsconfig for electron exists
      # Adjust the output dir (-outDir) if needed
      npx tsc --project platforms/desktop/tsconfig.json --outDir dist/desktop || {
        log::error "Failed to build Electron scripts. Ensure platforms/desktop/tsconfig.json is configured."; exit "$ERROR_BUILD_FAILED";
      }
      # Rename output to .cjs to explicitly mark as CommonJS
      mv dist/desktop/main.js dist/desktop/main.cjs || { log::error "Failed to rename main.js to main.cjs"; exit "$ERROR_BUILD_FAILED"; }
      mv dist/desktop/preload.js dist/desktop/preload.cjs || { log::error "Failed to rename preload.js to preload.cjs"; exit "$ERROR_BUILD_FAILED"; }
      log::success "Electron scripts built and renamed to .cjs."
    fi

    log::header "🎁 Preparing build artifacts..."
    local build_dir="${DEST_DIR}/${VERSION}"
    # Where to put build artifacts
    local artifacts_dir="${build_dir}/artifacts"
    # Where to put bundles
    local bundles_dir="${build_dir}/bundles"

    # Collect artifacts based on bundle types
    for b in "${BUNDLES[@]}"; do
        case "$b" in
            zip)
                log::info "Building ZIP bundle..."
                zip::copy_project "${artifacts_dir}"
                ;;
            cli)
                log::info "Building CLI executables..."
                package_cli
                ;;
            *)
                log::warning "Unknown bundle type: $b"
                ;;
        esac
    done

    # Collect Docker/Kubernetes artifacts
    for a in "${ARTIFACTS[@]}"; do
        case "$a" in
            docker)
                docker::build_artifacts "$artifacts_dir"
                ;;
            k8s)
                log::info "Building Kubernetes artifacts (stub)"
                # TODO: Add k8s build logic
                ;;
            *)
                log::warning "Unknown artifact type: $a";
                ;;
        esac
    done

    # Process platform binaries (e.g. Desktop App)
    for c in "${BINARIES[@]}"; do
        local target_platform=""
        case "$c" in
            windows)
                log::info "Building Windows Desktop App (Electron)..."
                # Ensure Wine is installed using the robust method
                install_wine_robustly
                target_platform="--win --x64"
                ;;
            mac)
                log::info "Building macOS Desktop App (Electron)..."
                target_platform="--mac --x64"
                ;;
            linux)
                log::info "Building Linux Desktop App (Electron)..."
                target_platform="--linux --x64"
                ;;
            # android/ios are likely mobile builds, not desktop - keeping stubs
            android)
                log::info "Building Android package..."
                bash "${MAIN_DIR}/../helpers/build/googlePlayStore.sh"
                continue # Skip electron-builder for android
                ;;
            ios)
                log::info "Building iOS package (stub)"
                # TODO: Add iOS build logic
                continue # Skip electron-builder for ios
                ;;
            *)
                log::warning "Unknown binary/desktop type: $c";
                continue
                ;;
        esac

        if [ -n "$target_platform" ]; then
            log::info "Running electron-builder for $c (this may take several minutes)..."
            # Pass platform and arch flags separately
            npx electron-builder $target_platform || {
              log::error "Electron build failed for $c."; exit "$ERROR_BUILD_FAILED";
            }
            log::success "Electron build completed for $c. Output in dist/desktop/"

            # Copying logic (optional, adjust as needed)
            if env::is_location_local "$DEST"; then
              local dest_dir="${DEST_DIR}/desktop/${c}/${VERSION}"
              local source_dir="${DEST_DIR}/desktop"
              mkdir -p "${dest_dir}"
              # Copy specific installer/package file(s)
              # This is an example, glob patterns might need adjustment
              find "${source_dir}" -maxdepth 1 -name "Vrooli*.$([ "$c" == "windows" ] && echo "exe" || ([ "$c" == "mac" ] && echo "dmg" || echo "AppImage"))" -exec cp {} "${dest_dir}/" \;
              log::success "Copied $c desktop artifact to ${dest_dir}"
            else
                log::warning "Remote destination not implemented for desktop app $c"
            fi
        fi

    done

    # Zip and compress the entire artifacts directory to the bundles directory
    zip::artifacts "${artifacts_dir}" "${bundles_dir}"

     # --- Remote Destination Handling ---
    if env::is_location_remote "$DEST"; then
        log::info "Setting up SSH connection to remote server ${SITE_IP}..."
        local ssh_key_path=$(keyless_ssh::get_key_path)
        keyless_ssh::connect

        log::info "Ensuring remote bundles directory ${SITE_IP}:${build_dir} exists and is empty..."
        ssh -i "$ssh_key_path" "root@${SITE_IP}" "mkdir -p ${build_dir} && rm -rf ${build_dir}/*" || {
            log::error "Failed to create or clean remote bundles directory ${SITE_IP}:${build_dir}"
            exit "$ERROR_REMOTE_OPERATION_FAILED"
        }

        log::info "Copying compressed build artifacts to ${SITE_IP}:${bundles_dir}..."
        rsync -avz --progress -e "ssh -i $ssh_key_path" "${bundles_dir}/artifacts.zip.gz" "root@${SITE_IP}:${bundles_dir}/" || {
            log::error "Failed to copy compressed build artifacts to ${SITE_IP}:${bundles_dir}"
            exit "$ERROR_REMOTE_OPERATION_FAILED"
        }
        log::success "Compressed build artifacts copied to ${SITE_IP}:${bundles_dir}"

        log::info "Unzipping compressed build artifacts on remote server at ${bundles_dir} to ${artifacts_dir}..."
        ssh -i "$ssh_key_path" "root@${SITE_IP}" "tar -xzf ${bundles_dir}/artifacts.zip.gz -C ${artifacts_dir}" || {
            log::error "Failed to unzip compressed build artifacts on remote server ${SITE_IP}"
            exit "$ERROR_REMOTE_OPERATION_FAILED"
        }
        log::success "Compressed build artifacts unzipped on ${SITE_IP}:${bundles_dir}"

        log::info "Cleaning up remote tarball..."
        ssh -i "$ssh_key_path" "root@${SITE_IP}" "rm -f ${bundles_dir}/artifacts.zip.gz"

        log::success "✅ Remote copy completed. Artifacts available at ${SITE_IP}:${artifacts_dir}"
        log::info "You can now run deploy.sh on the remote server (${SITE_IP})."
    else
        log::success "✅ Local copy completed. Artifacts available at ${artifacts_dir}"
        log::info "You can now run deploy.sh on the local server."
    fi
}

build::main "$@" 