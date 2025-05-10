#!/usr/bin/env bash
set -euo pipefail
DESCRIPTION="Builds specified artifacts for the Vrooli project, as preparation for deployment."

MAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/args.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/env.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/flow.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/locations.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/log.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/system.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/version.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/build/index.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/build/artifacts/index.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/build/binaries/index.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/build/bundles/index.sh"

parse_arguments() {
    args::reset

    args::register_help
    args::register_sudo_mode
    args::register_yes
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
        --flag "l" \
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

    # Assign default values for BUNDLES
    # Check if array is not empty before accessing first element
    if [ ${#BUNDLES[@]} -eq 0 ] || { [ ${#BUNDLES[@]} -gt 0 ] && [ "${BUNDLES[0]}" == "all" ]; }; then
        BUNDLES=("zip" "cli")
    fi

    # Assign default values for ARTIFACTS
    # Check if array is not empty before accessing first element
    if [ ${#ARTIFACTS[@]} -eq 0 ] || { [ ${#ARTIFACTS[@]} -gt 0 ] && [ "${ARTIFACTS[0]}" == "all" ]; }; then
        ARTIFACTS=("docker" "k8s")
    fi

    # Handle BINARIES: 'all' or specific list (empty list if default "" is used)
    # Check if the array is not empty before accessing the first element
    if [ ${#BINARIES[@]} -gt 0 ] && [ "${BINARIES[0]}" == "all" ]; then
        # Explicitly 'all' provided
        BINARIES=("windows" "mac" "linux" "android" "ios")
    fi
    # Otherwise, BINARIES is either the user-provided list or empty (from default="")

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

main() {
    parse_arguments "$@"
    log::header "🔨 Starting build for ${ENVIRONMENT} environment..."

    load_secrets
    construct_derived_secrets

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

    # Process bundle types
    for b in "${BUNDLES[@]}"; do
        case "$b" in
            zip)
                log::info "Building ZIP bundle..."
                zip_artifacts "${ENVIRONMENT}" "${VERSION}"
                ;;
            cli)
                log::info "Building CLI executables..."
                package_cli
                ;;
            *)
                log::warning "Unknown bundle type: $b"
                ;;
        esac

        if [ "$DEST" = "local" ]; then
            local dest_dir="${DEST_DIR}/bundles/${b}/${VERSION}"
            mkdir -p "${dest_dir}"
            local source_dir="${REMOTE_DIST_DIR}/${VERSION}"
            if [ -d "${source_dir}" ]; then
              cp -r "${source_dir}"/* "${dest_dir}/"
              log::success "Copied bundle ${b} version ${VERSION} to ${dest_dir}"
            else
              log::warning "Source directory ${source_dir} not found for bundle ${b}. Skipping copy."
            fi
        else
            log::warning "Remote destination not implemented for bundle $b"
        fi
    done

    # Compress build artifacts for distribution
    log::info "Compressing build artifacts for Docker deployments..."
    local out_dir="${REMOTE_DIST_DIR}/${VERSION}"
    mkdir -p "$out_dir"
    # Archive package dist directories
    pushd "${PACKAGES_DIR}" >/dev/null || { log::error "Failed to change to packages directory"; exit "$ERROR_BUILD_FAILED"; }
    tar -czf "$out_dir/build.tar.gz" ui/dist server/dist shared/dist 2>/dev/null || {
        popd >/dev/null
        log::error "Failed to compress build artifacts"
        exit "$ERROR_BUILD_FAILED"
    }
    popd >/dev/null
    log::success "Build artifacts compressed to $out_dir/build.tar.gz"

    # Process container artifacts
    for a in "${ARTIFACTS[@]}"; do
        case "$a" in
            docker)
                log::info "Building Docker artifacts..."
                # Always use docker-compose-prod.yml
                local compose_file="${ROOT_DIR}/docker-compose-prod.yml"
                log::info "Using Docker Compose file: $compose_file"
                # Navigate to project root
                pushd "${ROOT_DIR}" >/dev/null || { log::error "Cannot change to project root"; exit "$ERROR_BUILD_FAILED"; }
                # Build Docker images
                if system::is_command "docker compose"; then
                    docker compose -f "$compose_file" build --no-cache --progress=plain
                elif system::is_command "docker-compose"; then
                    docker-compose -f "$compose_file" build --no-cache
                else
                    log::error "No Docker Compose available to build images"
                    popd >/dev/null
                    exit "$ERROR_BUILD_FAILED"
                fi
                popd >/dev/null
                # Pull base service images
                log::info "Pulling base images"
                docker pull redis:7.4.0-alpine
                docker pull ankane/pgvector:v0.4.4
                # Determine tag suffix for custom images (always use prod)
                local suffix="prod"
                # Collect images to save
                local images=("ui:${suffix}" "server:${suffix}" "jobs:${suffix}" "redis:7.4.0-alpine" "ankane/pgvector:v0.4.4")
                local available_images=()
                for img in "${images[@]}"; do
                    if docker image inspect "$img" >/dev/null 2>&1; then
                        available_images+=("$img")
                    else
                        log::warning "Image $img not found, skipping"
                    fi
                done
                if [[ ${#available_images[@]} -eq 0 ]]; then
                    log::error "No Docker images available to save"
                    exit "$ERROR_BUILD_FAILED"
                fi
                # Save and compress Docker images
                local images_tar="$out_dir/docker-images.tar"
                docker save -o "$images_tar" "${available_images[@]}"
                if [[ $? -ne 0 ]]; then
                    log::error "Failed to save Docker images"
                    exit "$ERROR_BUILD_FAILED"
                fi
                gzip -f "$images_tar"
                log::success "Docker images saved to $out_dir/docker-images.tar.gz"
                ;;
            k8s)
                log::info "Building Kubernetes artifacts (stub)"
                # TODO: Add k8s build logic
                ;;
            *)
                log::warning "Unknown artifact type: $a";
                ;;
        esac
        if [ "$DEST" = "local" ]; then
            log::warning "Local copy for artifact $a not implemented"
        else
            log::warning "Remote destination not implemented for artifact $a"
        fi
    done

    # Process platform binaries (now Desktop Apps)
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
            if [ "$DEST" = "local" ]; then
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

    # --- Remote Destination Handling ---
    if [ "$DEST" = "remote" ]; then
        log::header "🚚 Preparing and copying build artifacts to remote server..."
        local remote_tmp_dir="${REMOTE_DIST_DIR}"
        local local_source_dir="${DEST_DIR}"
        local remote_dest_dir="${remote_tmp_dir}/${VERSION}"
        local tarball_name="vrooli-build-${VERSION}.tar.gz"
        local local_tarball_path="${remote_tmp_dir}/${tarball_name}" # Create tarball locally in /var/tmp

        if [ ! -d "${local_source_dir}" ] || [ -z "$(ls -A "${local_source_dir}")" ]; then
            log::error "Source directory ${local_source_dir} is empty or does not exist. Cannot proceed with remote copy."
            exit "$ERROR_INVALID_STATE"
        fi

        log::info "Creating tarball of build artifacts from ${local_source_dir}..."
        # Create the tarball in /var/tmp locally
        tar -czf "${local_tarball_path}" -C "${local_source_dir}" . || {
            log::error "Failed to create tarball ${local_tarball_path}"
            exit "$ERROR_BUILD_FAILED"
        }
        log::success "Created tarball: ${local_tarball_path}"

        log::info "Setting up SSH connection to ${SITE_IP}..."
        # Assuming keylessSsh.sh sets up keys correctly. Need to ensure SITE_IP is loaded.
        # shellcheck disable=SC1091
        source "${MAIN_DIR}/../helpers/utils/keylessSsh.sh"
        setup_ssh_key "${SITE_IP}" || {
            log::error "Failed to set up SSH key for ${SITE_IP}"
            exit "$ERROR_REMOTE_OPERATION_FAILED"
        }

        if ! flow::is_yes "$YES"; then
            log::prompt "About to copy ${tarball_name} to ${SITE_IP}:${remote_tmp_dir}. Proceed? (y/N)"
            read -r reply
            if [[ ! "$reply" =~ ^[Yy]$ ]]; then
                log::info "Aborted by user."
                # Clean up local tarball
                rm -f "${local_tarball_path}"
                exit "$EXIT_SUCCESS"
            fi
        fi

        log::info "Ensuring remote directory ${remote_dest_dir} exists and is empty..."
        ssh -i "$SSH_KEY_PATH" "root@${SITE_IP}" "mkdir -p ${remote_dest_dir} && rm -rf ${remote_dest_dir}/*" || {
            log::error "Failed to create or clean remote directory ${remote_dest_dir} on ${SITE_IP}"
            # Clean up local tarball
            rm -f "${local_tarball_path}"
            exit "$ERROR_REMOTE_OPERATION_FAILED"
        }

        log::info "Copying ${tarball_name} to ${SITE_IP}:${remote_tmp_dir}..."
        rsync -avz --progress -e "ssh -i $SSH_KEY_PATH" "${local_tarball_path}" "root@${SITE_IP}:${remote_tmp_dir}/" || {
            log::error "Failed to copy ${tarball_name} to ${SITE_IP}:${remote_tmp_dir}"
            # Clean up local tarball
            rm -f "${local_tarball_path}"
            exit "$ERROR_REMOTE_OPERATION_FAILED"
        }
        log::success "Tarball copied to ${SITE_IP}:${remote_tmp_dir}"

        log::info "Extracting tarball on remote server at ${remote_dest_dir}..."
        ssh -i "$SSH_KEY_PATH" "root@${SITE_IP}" "tar -xzf ${remote_tmp_dir}/${tarball_name} -C ${remote_dest_dir}" || {
            log::error "Failed to extract tarball on remote server ${SITE_IP}"
            # Potentially leave remote tarball for debugging? Or attempt cleanup?
            # Clean up local tarball
            rm -f "${local_tarball_path}"
            exit "$ERROR_REMOTE_OPERATION_FAILED"
        }
        log::success "Artifacts extracted to ${SITE_IP}:${remote_dest_dir}"

        log::info "Cleaning up local and remote tarballs..."
        rm -f "${local_tarball_path}"
        ssh -i "$SSH_KEY_PATH" "root@${SITE_IP}" "rm -f ${remote_tmp_dir}/${tarball_name}"

        log::success "✅ Remote copy completed. Artifacts available at ${SITE_IP}:${remote_dest_dir}"
        log::info "You can now run deploy.sh on the remote server (${SITE_IP})."
    fi

    log::success "✅ Build process completed for ${ENVIRONMENT} environment."
}

main "$@" 