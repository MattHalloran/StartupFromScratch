#!/usr/bin/env bash
# This script generates a public/private key pair for JWT signing
set -euo pipefail

UTILS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${UTILS_DIR}/locations.sh"
# shellcheck disable=SC1091
source "${UTILS_DIR}/logging.sh"
# shellcheck disable=SC1091
source "${UTILS_DIR}/exit_codes.sh"

do_jwt_keys_exist() {
    # Return success only if both keys exist, error if one exists, otherwise indicate no keys exist
    if [ -f "${JWT_PUB_KEY_FILE}" ] && [ -f "${JWT_PRIV_KEY_FILE}" ]; then
        info "JWT keys already exist. Delete them first if you want to generate new ones."
        return 0
    elif [ -f "${JWT_PUB_KEY_FILE}" ] || [ -f "${JWT_PRIV_KEY_FILE}" ]; then
        error "One JWT key exists, but not the other. Delete them both and try again."
        exit $ERROR_JWT_FILE_MISSING
    else
        # No JWT keys present
        return 1
    fi
}

generate_jwt_key_pair() {
    if do_jwt_keys_exist; then
        return 0
    fi

    # Use openssl to generate private key and public key
    header "Generating JWT key pair for authentication"
    openssl genpkey -algorithm RSA -out "${JWT_PRIV_KEY_FILE}" -pkeyopt rsa_keygen_bits:2048
    openssl rsa -pubout -in "${JWT_PRIV_KEY_FILE}" -out "${JWT_PUB_KEY_FILE}"
    info "JWT keys generated and saved to ${JWT_PRIV_KEY_FILE} and ${JWT_PUB_KEY_FILE} in the root directory of the project."
}
