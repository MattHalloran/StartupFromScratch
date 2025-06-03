#!/usr/bin/env bash
# Posix-compliant script to setup and build everything needed to publish to the Google Play Store
set -euo pipefail

BUILD_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${BUILD_DIR}/../utils/flow.sh"
# shellcheck disable=SC1091
source "${BUILD_DIR}/../utils/log.sh"
# shellcheck disable=SC1091
source "${BUILD_DIR}/../utils/system.sh"
# shellcheck disable=SC1091
source "${BUILD_DIR}/../utils/var.sh"

googlePlayStore::get_env_vars() {
    # Keystore details
    KEYSTORE_PATH="${KEYSTORE_PATH:-${var_ROOT_DIR}/upload-keystore.jks}"
    KEYSTORE_ALIAS="${KEYSTORE_ALIAS:-upload}"
    KEYSTORE_PASSWORD="${KEYSTORE_PASSWORD:-${GOOGLE_PLAY_KEYSTORE_PASSWORD-}}"

    # Keystore Distinguished Name (DN) components
    KEYSTORE_DN_CN="${KEYSTORE_DN_CN-}" # Common Name (e.g., Your Full Name)
    KEYSTORE_DN_OU="${KEYSTORE_DN_OU-}" # Organizational Unit
    KEYSTORE_DN_O="${KEYSTORE_DN_O-}"  # Organization
    KEYSTORE_DN_L="${KEYSTORE_DN_L-}"  # Locality/City
    KEYSTORE_DN_ST="${KEYSTORE_DN_ST-}" # State/Province
    KEYSTORE_DN_C="${KEYSTORE_DN_C-}"   # Country Code (2 letters)

    # Android App Details
    ANDROID_PACKAGE_NAME="${ANDROID_PACKAGE_NAME-}"
    # Optional: A second SHA-256 fingerprint for assetlinks.json
    GOOGLE_PLAY_DOMAIN_FINGERPRINT="${GOOGLE_PLAY_DOMAIN_FINGERPRINT-}"
}

# Check for keytool (JDK) and openssl, and install if not available.
googlePlayStore::install_dependencies() {
    log::info "Checking for keytool (Java Development Kit)..."
    if ! system::is_command "keytool"; then
        log::info "keytool not found. Attempting to install default-jdk..."
        if ! system::install_pkg "default-jdk"; then
            log::error "Failed to install default-jdk. keytool is required for Android signing."
            log::error "Please install JDK manually and ensure keytool is in your PATH."
            return 1
        fi
        log::success "default-jdk installed successfully. keytool should now be available."
    else
        log::info "keytool is already installed."
    fi

    log::info "Checking for openssl..."
    if ! system::is_command "openssl"; then
        log::info "openssl not found. Attempting to install openssl..."
        if ! system::install_pkg "openssl"; then
            log::error "Failed to install openssl. It is required for generating assetlinks.json."
            return 1
        fi
        log::success "openssl installed successfully."
    else
        log::info "openssl is already installed."
    fi
    
    return 0
}

# Sets up the keystore file for the Google Play Store
googlePlayStore::setup_keystore() {
    log::header "Setting up Google Play Keystore..."
    
    # Ensure KEYSTORE_PASSWORD etc. are populated
    # Note: googlePlayStore::get_env_vars was already called by the main function
    if [ -z "${KEYSTORE_PASSWORD}" ]; then
        log::info "GOOGLE_PLAY_KEYSTORE_PASSWORD (or KEYSTORE_PASSWORD) is not set. Skipping keystore setup."
        return 0
    fi

    if [ -f "${KEYSTORE_PATH}" ]; then
        log::info "Keystore file already exists at ${KEYSTORE_PATH}. Skipping generation."
        return 0
    fi

    log::info "Keystore file not found at ${KEYSTORE_PATH}. Attempting to generate..."

    # Check for all required DN components
    local missing_dn_vars=0
    for var_name in KEYSTORE_DN_CN KEYSTORE_DN_OU KEYSTORE_DN_O KEYSTORE_DN_L KEYSTORE_DN_ST KEYSTORE_DN_C; do
        if [ -z "${!var_name}" ]; then
            log::error "Required environment variable ${var_name} for keystore DN is not set."
            missing_dn_vars=1
        fi
    done

    if [ "${missing_dn_vars}" -eq 1 ]; then
        log::error "Cannot generate keystore due to missing DN information. Please set all KEYSTORE_DN_* variables in your .env file."
        return 1
    fi

    local dname_string="CN=${KEYSTORE_DN_CN}, OU=${KEYSTORE_DN_OU}, O=${KEYSTORE_DN_O}, L=${KEYSTORE_DN_L}, ST=${KEYSTORE_DN_ST}, C=${KEYSTORE_DN_C}"

    log::info "Generating keystore file for Google Play Store with DName: ${dname_string}"
    if keytool -genkey -v \
        -keystore "${KEYSTORE_PATH}" \
        -alias "${KEYSTORE_ALIAS}" \
        -keyalg RSA -keysize 2048 \
        -validity 10000 \
        -storepass "${KEYSTORE_PASSWORD}" \
        -dname "${dname_string}"; then
        log::success "Keystore file generated successfully at ${KEYSTORE_PATH}"
    else
        log::error "Failed to generate keystore file."
        return 1
    fi
    return 0
}

googlePlayStore::create_assetlinks_file() {
    log::header "Handling assetlinks.json for Google Play..."

    if [ -z "${KEYSTORE_PASSWORD}" ]; then
        log::info "GOOGLE_PLAY_KEYSTORE_PASSWORD is not set. Skipping assetlinks.json creation."
        return 0
    fi

    if [ ! -f "${KEYSTORE_PATH}" ]; then
        log::warning "Keystore file not found at ${KEYSTORE_PATH}. Cannot create assetlinks.json without it."
        log::warning "Ensure keystore setup runs successfully first."
        return 1
    fi

    if [ -z "${ANDROID_PACKAGE_NAME}" ]; then
        log::warning "ANDROID_PACKAGE_NAME is not set. Cannot create assetlinks.json without the package name."
        return 1
    fi

    local well_known_dir="${var_ROOT_DIR}/packages/ui/dist/.well-known"
    local assetlinks_file="${well_known_dir}/assetlinks.json"

    log::info "Ensuring directory exists: ${well_known_dir}"
    if ! mkdir -p "${well_known_dir}"; then
        log::error "Failed to create directory ${well_known_dir}."
        return 1
    fi

    log::info "Exporting certificate from keystore to generate SHA-256 fingerprint..."
    # Use a temporary PEM file
    local temp_pem_path
    temp_pem_path="$(mktemp)"
    trap "rm -f ${temp_pem_path}" EXIT
    
    if ! keytool -export -rfc -keystore "${KEYSTORE_PATH}" -alias "${KEYSTORE_ALIAS}" -file "${temp_pem_path}" -storepass "${KEYSTORE_PASSWORD}"; then
        log::error "PEM file could not be generated from keystore. Cannot create assetlinks.json."
        return 1
    fi

    log::info "Extracting SHA-256 fingerprint from certificate..."
    local extracted_fingerprint
    if ! extracted_fingerprint=$(openssl x509 -in "${temp_pem_path}" -fingerprint -sha256 -noout | sed 's/SHA256 Fingerprint=//g' | tr -d ':' | tr 'a-z' 'A-Z'); then    
        log::error "SHA-256 fingerprint could not be extracted using openssl."
        return 1
    fi

    if [ -z "${extracted_fingerprint}" ]; then
        log::error "Extracted SHA-256 fingerprint is empty."
        return 1
    else
        log::success "SHA-256 fingerprint extracted: ${extracted_fingerprint}"
    fi

    log::info "Creating ${assetlinks_file} for package ${ANDROID_PACKAGE_NAME}..."
    
    local fingerprints_json_array="\"${extracted_fingerprint}\""
    if [ -n "${GOOGLE_PLAY_DOMAIN_FINGERPRINT}" ]; then
        # Ensure the domain fingerprint is also colon-less and uppercase if needed, or formatted consistently
        local formatted_domain_fingerprint=$(echo "${GOOGLE_PLAY_DOMAIN_FINGERPRINT}" | tr -d ':' | tr 'a-z' 'A-Z')
        fingerprints_json_array="${fingerprints_json_array}, \"${formatted_domain_fingerprint}\""
    fi

    # Using printf for safer JSON construction
    if ! printf '[{
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "%s",
      "sha256_cert_fingerprints": [%s]
    }
}]' "${ANDROID_PACKAGE_NAME}" "${fingerprints_json_array}" > "${assetlinks_file}"; then
        log::error "Failed to write ${assetlinks_file}."
        return 1
    fi

    log::success "${assetlinks_file} created successfully."
    return 0
}


googlePlayStore::main() {
    googlePlayStore::get_env_vars

    # Only proceed if the primary trigger (keystore password) is set
    if [ -z "${KEYSTORE_PASSWORD}" ]; then
        log::info "GOOGLE_PLAY_KEYSTORE_PASSWORD is not set. Google Play Store specific build steps will be skipped."
        exit 0
    fi

    if ! googlePlayStore::install_dependencies;
        log::error "Dependency installation (JDK/openssl) failed. Aborting Google Play Store build steps."
        exit 1
    fi

    if ! googlePlayStore::setup_keystore; then
        log::error "Keystore setup failed. Aborting Google Play Store build steps."
        exit 1
    fi

    if ! googlePlayStore::create_assetlinks_file; then
        log::error "Assetlinks.json creation failed."
        exit 1 
    fi

    log::success "Google Play Store prerequisite setup completed successfully."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    googlePlayStore::main
fi
