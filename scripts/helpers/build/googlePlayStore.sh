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

get_env_vars() {
    if [ -z "${KEYSTORE_PATH:-}" ]; then
        KEYSTORE_PATH="${ROOT_DIR}/upload-keystore.jks"
    fi
    if [ -z "${KEYSTORE_ALIAS:-}" ]; then
        KEYSTORE_ALIAS="upload"
    fi
    if [ -z "${KEYSTORE_PASSWORD:-}" ]; then
        KEYSTORE_PASSWORD="${GOOGLE_PLAY_KEYSTORE_PASSWORD}"
    fi
}

# Check for keytool and install JDK if it's not available. This is
# used for signing the app in the Google Play store
install_jdk() {
    if ! system::is_command "keytool"; then
        system::should_run_update && system::update
        system::install_pkg "default-jdk"
        log::success "JDK installed. keytool should now be available."
    else
        log::info "keytool is already installed"
    fi
}

# Sets up the keystore file for the Google Play Store
setup_keystore() {
    get_env_vars

    # Check if keystore file exists
    if [ ! -f "${KEYSTORE_PATH}" ]; then
        if flow::is_yes "$SKIP_CONFIRMATIONS"; then
            log::info "Keystore file not found. This is needed to upload the app the Google Play store. Creating keystore file..."
            REPLY="y"
        else
            log::prompt "Keystore file not found. This is needed to upload the app the Google Play store. Would you like to create the file? (Y/n)"
            read -n1 -r REPLY
            echo
        fi
        if flow::is_yes "$REPLY"; then
            setup_keystore

            # Generate the keystore file
            log::header "Generating keystore file..."
            log::info "Before we begin, you'll need to provide some information for the keystore certificate:"
            log::info "This information should be accurate, but it does not have to match exactly with the information you used to register your Google Play account."
            log::info "1. First and Last Name: Your full legal name. Example: John Doe"
            log::info "2. Organizational Unit: The department within your organization managing the key. Example: IT"
            log::info "3. Organization: The legal name of your company or organization. Example: Vrooli"
            log::info "4. City or Locality: The city where your organization is based. Example: New York City"
            log::info "5. State or Province: The state or province where your organization is located. Example: New York"
            log::info "6. Country Code: The two-letter ISO code for the country of your organization. Example: US"
            log::info "This information helps to identify the holder of the key."
            if flow::is_yes "$SKIP_CONFIRMATIONS"; then
                log::info "Skipping confirmation..."
                REPLY="y"
            else
                log::prompt "Press any key to continue..."
                read -n1 -r -s
            fi

            log::info "Generating keystore file for Google Play Store"
            keytool -genkey -v -keystore "${KEYSTORE_PATH}" -alias "${KEYSTORE_ALIAS}" -keyalg RSA -keysize 2048 -validity 10000 -storepass "${KEYSTORE_PASSWORD}"
        fi
    fi
}



create_assetlinks_file() {
    get_env_vars

    # Create assetlinks.json file for Google Play Store
    if [ -f "${KEYSTORE_PATH}" ]; then
        log::header "Creating dist/.well-known/assetlinks.json file so Google can verify the app with the website..."
        # Export the PEM file from keystore
        PEM_PATH="${ROOT_DIR}/upload_certificate.pem"
        if ! keytool -export -rfc -keystore "${KEYSTORE_PATH}" -alias "${KEYSTORE_ALIAS}" -file "${PEM_PATH}" -storepass "${KEYSTORE_PASSWORD}"; then
            log::warning "PEM file could not be generated. The app cannot be uploaded to the Google Play store without it."
            return 1
        fi

        # Extract SHA-256 fingerprint
        if ! GOOGLE_PLAY_FINGERPRINT=$(keytool -list -keystore "${KEYSTORE_PATH}" -alias "${KEYSTORE_ALIAS}" -storepass "${KEYSTORE_PASSWORD}" -v | grep "SHA256:" | awk '{ print $2 }'); then
            log::warning "SHA-256 fingerprint could not be extracted. The app cannot be uploaded to the Google Play store without it."
            return 1
        else
            log::success "SHA-256 fingerprint extracted successfully: $GOOGLE_PLAY_FINGERPRINT"
        fi

        # Create assetlinks.json file for Google Play Store
        if [ -n "${GOOGLE_PLAY_FINGERPRINT}" ]; then
            log::info "Creating dist/.well-known/assetlinks.json file for Google Play Trusted Web Activity (TWA)..."
            mkdir -p "${ROOT_DIR}/packages/ui/dist/.well-known"
            cd "${ROOT_DIR}/packages/ui/dist/.well-known"
            {
              echo "[{"
              echo "    \"relation\": [\"delegate_permission/common.handle_all_urls\"],"
              echo "    \"target\": {"
              echo "      \"namespace\": \"android_app\","   
              echo "      \"package_name\": \"com.vrooli.twa\","   
              if [ -n "${GOOGLE_PLAY_DOMAIN_FINGERPRINT}" ]; then
                echo "      \"sha256_cert_fingerprints\": ["
                echo "          \"${GOOGLE_PLAY_FINGERPRINT}\","
                echo "          \"${GOOGLE_PLAY_DOMAIN_FINGERPRINT}\""
                echo "      ]"
              else
                echo "      \"sha256_cert_fingerprints\": [\"${GOOGLE_PLAY_FINGERPRINT}\"]"
              fi
              echo "    }"
              echo "}]"
            } >assetlinks.json
            cd "${BUILD_DIR}/.."
        fi
    fi
}
