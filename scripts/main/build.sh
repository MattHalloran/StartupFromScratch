#!/usr/bin/env bash
set -euo pipefail
DESCRIPTION="Builds specified artifacts for the Vrooli project, as preparation for deployment."

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
        --default ""

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
    
    export SUDO_MODE=$(arg_get "sudo-mode")
    export YES=$(arg_get "yes")
    export ENVIRONMENT=$(arg_get "environment")
    # Read comma-separated strings into temp variables
    local bundles_str=$(arg_get "bundles")
    local artifacts_str=$(arg_get "artifacts")
    local binaries_str=$(arg_get "binaries")
    export DEST=$(arg_get "dest")
    export TEST=$(arg_get "test")
    export LINT=$(arg_get "lint")
    export VERSION=$(arg_get "version")

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
    local build_desktop="NO"
    # Check array length correctly
    if [ ${#BINARIES[@]} -gt 0 ]; then
      build_desktop="YES"
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
            zip)
                info "Building ZIP bundle..."
                zip_artifacts "${ENVIRONMENT}" "${VERSION}"
                ;;
            cli)
                info "Building CLI executables..."
                package_cli
                ;;
            *)
                warning "Unknown bundle type: $b"
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
              warning "Source directory ${source_dir} not found for bundle ${b}. Skipping copy."
            fi
        else
            warning "Remote destination not implemented for bundle $b"
        fi
    done

    # Compress build artifacts for distribution
    info "Compressing build artifacts for Docker deployments..."
    local out_dir="/var/tmp/${VERSION}"
    mkdir -p "$out_dir"
    # Archive package dist directories
    pushd "${HERE}/../../packages" >/dev/null || { error "Failed to change to packages directory"; exit "$ERROR_BUILD_FAILED"; }
    tar -czf "$out_dir/build.tar.gz" ui/dist server/dist shared/dist 2>/dev/null || {
        popd >/dev/null
        error "Failed to compress build artifacts"
        exit "$ERROR_BUILD_FAILED"
    }
    popd >/dev/null
    success "Build artifacts compressed to $out_dir/build.tar.gz"

    # Process container artifacts
    for a in "${ARTIFACTS[@]}"; do
        case "$a" in
            docker)
                info "Building Docker artifacts..."
                # Always use docker-compose-prod.yml
                local compose_file="${HERE}/../../docker-compose-prod.yml"
                info "Using Docker Compose file: $compose_file"
                # Navigate to project root
                pushd "${HERE}/../.." >/dev/null || { error "Cannot change to project root"; exit "$ERROR_BUILD_FAILED"; }
                # Build Docker images
                if command -v docker compose >/dev/null 2>&1; then
                    docker compose -f "$compose_file" build --no-cache --progress=plain
                elif command -v docker-compose >/dev/null 2>&1; then
                    docker-compose -f "$compose_file" build --no-cache
                else
                    error "No Docker Compose available to build images"
                    popd >/dev/null
                    exit "$ERROR_BUILD_FAILED"
                fi
                popd >/dev/null
                # Pull base service images
                info "Pulling base images"
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
                        warning "Image $img not found, skipping"
                    fi
                done
                if [[ ${#available_images[@]} -eq 0 ]]; then
                    error "No Docker images available to save"
                    exit "$ERROR_BUILD_FAILED"
                fi
                # Save and compress Docker images
                local images_tar="$out_dir/docker-images.tar"
                docker save -o "$images_tar" "${available_images[@]}"
                if [[ $? -ne 0 ]]; then
                    error "Failed to save Docker images"
                    exit "$ERROR_BUILD_FAILED"
                fi
                gzip -f "$images_tar"
                success "Docker images saved to $out_dir/docker-images.tar.gz"
                ;;
            k8s)
                info "Building Kubernetes artifacts (stub)"
                # TODO: Add k8s build logic
                ;;
            *)
                warning "Unknown artifact type: $a";
                ;;
        esac
        if [ "$DEST" = "local" ]; then
            warning "Local copy for artifact $a not implemented"
        else
            warning "Remote destination not implemented for artifact $a"
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
                warning "Unknown binary/desktop type: $c";
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
                warning "Remote destination not implemented for desktop app $c"
            fi
        fi

    done

    # --- Remote Destination Handling ---
    if [ "$DEST" = "remote" ]; then
        header "🚚 Preparing and copying build artifacts to remote server..."
        local remote_tmp_dir="/var/tmp"
        local local_source_dir="/var/tmp/${VERSION}"
        local remote_dest_dir="${remote_tmp_dir}/${VERSION}"
        local tarball_name="vrooli-build-${VERSION}.tar.gz"
        local local_tarball_path="${remote_tmp_dir}/${tarball_name}" # Create tarball locally in /var/tmp

        if [ ! -d "${local_source_dir}" ] || [ -z "$(ls -A "${local_source_dir}")" ]; then
            error "Source directory ${local_source_dir} is empty or does not exist. Cannot proceed with remote copy."
            exit "$ERROR_INVALID_STATE"
        fi

        info "Creating tarball of build artifacts from ${local_source_dir}..."
        # Create the tarball in /var/tmp locally
        tar -czf "${local_tarball_path}" -C "${local_source_dir}" . || {
            error "Failed to create tarball ${local_tarball_path}"
            exit "$ERROR_BUILD_FAILED"
        }
        success "Created tarball: ${local_tarball_path}"

        info "Setting up SSH connection to ${SITE_IP}..."
        # Assuming keylessSsh.sh sets up keys correctly. Need to ensure SITE_IP is loaded.
        # shellcheck disable=SC1091
        source "${HERE}/../utils/keylessSsh.sh"
        setup_ssh_key "${SITE_IP}" || {
            error "Failed to set up SSH key for ${SITE_IP}"
            exit "$ERROR_REMOTE_OPERATION_FAILED"
        }

        if ! is_yes "$YES"; then
            prompt "About to copy ${tarball_name} to ${SITE_IP}:${remote_tmp_dir}. Proceed? (y/N)"
            read -r reply
            if [[ ! "$reply" =~ ^[Yy]$ ]]; then
                info "Aborted by user."
                # Clean up local tarball
                rm -f "${local_tarball_path}"
                exit "$EXIT_SUCCESS"
            fi
        fi

        info "Ensuring remote directory ${remote_dest_dir} exists and is empty..."
        ssh -i "$SSH_KEY_PATH" "root@${SITE_IP}" "mkdir -p ${remote_dest_dir} && rm -rf ${remote_dest_dir}/*" || {
            error "Failed to create or clean remote directory ${remote_dest_dir} on ${SITE_IP}"
            # Clean up local tarball
            rm -f "${local_tarball_path}"
            exit "$ERROR_REMOTE_OPERATION_FAILED"
        }

        info "Copying ${tarball_name} to ${SITE_IP}:${remote_tmp_dir}..."
        rsync -avz --progress -e "ssh -i $SSH_KEY_PATH" "${local_tarball_path}" "root@${SITE_IP}:${remote_tmp_dir}/" || {
            error "Failed to copy ${tarball_name} to ${SITE_IP}:${remote_tmp_dir}"
            # Clean up local tarball
            rm -f "${local_tarball_path}"
            exit "$ERROR_REMOTE_OPERATION_FAILED"
        }
        success "Tarball copied to ${SITE_IP}:${remote_tmp_dir}"

        info "Extracting tarball on remote server at ${remote_dest_dir}..."
        ssh -i "$SSH_KEY_PATH" "root@${SITE_IP}" "tar -xzf ${remote_tmp_dir}/${tarball_name} -C ${remote_dest_dir}" || {
            error "Failed to extract tarball on remote server ${SITE_IP}"
            # Potentially leave remote tarball for debugging? Or attempt cleanup?
            # Clean up local tarball
            rm -f "${local_tarball_path}"
            exit "$ERROR_REMOTE_OPERATION_FAILED"
        }
        success "Artifacts extracted to ${SITE_IP}:${remote_dest_dir}"

        info "Cleaning up local and remote tarballs..."
        rm -f "${local_tarball_path}"
        ssh -i "$SSH_KEY_PATH" "root@${SITE_IP}" "rm -f ${remote_tmp_dir}/${tarball_name}"

        success "✅ Remote copy completed. Artifacts available at ${SITE_IP}:${remote_dest_dir}"
        info "You can now run deploy.sh on the remote server (${SITE_IP})."
    fi

    success "✅ Build process completed for ${ENVIRONMENT} environment."
}

main "$@" 