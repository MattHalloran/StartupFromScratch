#!/bin/bash
# Posix-compliant script to setup and build everything needed to publish to the Google Play Store
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
KEYSTORE_PATH="${HERE}/../../upload-keystore.jks"
KEYSTORE_ALIAS="upload"
KEYSTORE_PASSWORD="${GOOGLE_PLAY_KEYSTORE_PASSWORD}"

source "${HERE}/../utils/index.sh"

# Check for keytool and install JDK if it's not available. This is
# used for signing the app in the Google Play store
install_jdk() {
    if ! command -v keytool &>/dev/null; then
        header "Installing JDK for keytool"
        sudo apt update
        sudo DEBIAN_FRONTEND=noninteractive apt install -y default-jdk
        success "JDK installed. keytool should now be available."
    else
        info "keytool is already installed"
    fi
}

# Sets up the keystore file for the Google Play Store
setup_keystore() {
    # Check if keystore file exists
    if [ ! -f "${KEYSTORE_PATH}" ]; then
        if is_yes "$SKIP_CONFIRMATIONS"; then
            info "Keystore file not found. This is needed to upload the app the Google Play store. Creating keystore file..."
            REPLY="y"
        else
            prompt "Keystore file not found. This is needed to upload the app the Google Play store. Would you like to create the file? (Y/n)"
            read -n1 -r REPLY
            echo
        fi
        if is_yes "$REPLY"; then
            setup_keystore

            # Generate the keystore file
            header "Generating keystore file..."
            info "Before we begin, you'll need to provide some information for the keystore certificate:"
            info "This information should be accurate, but it does not have to match exactly with the information you used to register your Google Play account."
            info "1. First and Last Name: Your full legal name. Example: John Doe"
            info "2. Organizational Unit: The department within your organization managing the key. Example: IT"
            info "3. Organization: The legal name of your company or organization. Example: Vrooli"
            info "4. City or Locality: The city where your organization is based. Example: New York City"
            info "5. State or Province: The state or province where your organization is located. Example: New York"
            info "6. Country Code: The two-letter ISO code for the country of your organization. Example: US"
            info "This information helps to identify the holder of the key."
            if is_yes "$SKIP_CONFIRMATIONS"; then
                info "Skipping confirmation..."
                REPLY="y"
            else
                prompt "Press any key to continue..."
                read -n1 -r -s
            fi

            run_step "Generating keystore file for Google Play Store" "keytool -genkey -v -keystore \"${KEYSTORE_PATH}\" -alias \"${KEYSTORE_ALIAS}\" -keyalg RSA -keysize 2048 -validity 10000 -storepass \"${KEYSTORE_PASSWORD}\""
        fi
    fi
}



create_assetlinks_file() {
    # Create assetlinks.json file for Google Play Store
    if [ -f "${KEYSTORE_PATH}" ]; then
        header "Creating dist/.well-known/assetlinks.json file so Google can verify the app with the website..."
        # Export the PEM file from keystore
        PEM_PATH="${HERE}/../upload_certificate.pem"
        keytool -export -rfc -keystore "${KEYSTORE_PATH}" -alias "${KEYSTORE_ALIAS}" -file "${PEM_PATH}" -storepass "${KEYSTORE_PASSWORD}"
        if [ $? -ne 0 ]; then
            warning "PEM file could not be generated. The app cannot be uploaded to the Google Play store without it."
            return 1
        fi

        # Extract SHA-256 fingerprint
        GOOGLE_PLAY_FINGERPRINT=$(keytool -list -keystore "${KEYSTORE_PATH}" -alias "${KEYSTORE_ALIAS}" -storepass "${KEYSTORE_PASSWORD}" -v | grep "SHA256:" | awk '{ print $2 }')
        if [ $? -ne 0 ]; then
            warning "SHA-256 fingerprint could not be extracted. The app cannot be uploaded to the Google Play store without it."
            return 1
        else
            success "SHA-256 fingerprint extracted successfully: $GOOGLE_PLAY_FINGERPRINT"
        fi

        # Create assetlinks.json file for Google Play Store
        if [ -z "${GOOGLE_PLAY_FINGERPRINT}" ]; then
            warning "GOOGLE_PLAY_FINGERPRINT is not set. Not creating dist/.well-known/assetlinks.json file for Google Play Trusted Web Activity (TWA)."
        else
            info "Creating dist/.well-known/assetlinks.json file for Google Play Trusted Web Activity (TWA)..."
            mkdir -p ${HERE}/../packages/ui/dist/.well-known
            cd ${HERE}/../packages/ui/dist/.well-known
            echo "[{" >assetlinks.json
            echo "    \"relation\": [\"delegate_permission/common.handle_all_urls\"]," >>assetlinks.json
            echo "    \"target\": {" >>assetlinks.json
            echo "      \"namespace\": \"android_app\"," >>assetlinks.json
            echo "      \"package_name\": \"com.vrooli.twa\"," >>assetlinks.json
            # Check if the GOOGLE_PLAY_DOMAIN_FINGERPRINT variable is set and append it to the array
            if [ ! -z "${GOOGLE_PLAY_DOMAIN_FINGERPRINT}" ]; then
                echo "      \"sha256_cert_fingerprints\": [" >>assetlinks.json
                echo "          \"${GOOGLE_PLAY_FINGERPRINT}\"," >>assetlinks.json
                echo "          \"${GOOGLE_PLAY_DOMAIN_FINGERPRINT}\"" >>assetlinks.json
                echo "      ]" >>assetlinks.json
            else
                echo "      \"sha256_cert_fingerprints\": [\"${GOOGLE_PLAY_FINGERPRINT}\"]" >>assetlinks.json
            fi
            echo "    }" >>assetlinks.json
            echo "}]" >>assetlinks.json
            cd ${HERE}/..
        fi
    fi
}
