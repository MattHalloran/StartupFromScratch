#!/usr/bin/env bash
# This script generates a public/private key pair for JWT signing
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$HERE"/../.. && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/logging.sh"
# shellcheck disable=SC1091
source "${HERE}/../utils/exit_codes.sh"

# # Go to root directory of the project
# cd "${HERE}/.."

PUB_KEY_NAME="${ROOT_DIR}/jwt_pub.pem"
PRIV_KEY_NAME="${ROOT_DIR}/jwt_priv.pem"

do_jwt_keys_exist() {
    # Return success only if both keys exist, error if one exists, otherwise indicate no keys exist
    if [ -f "${PUB_KEY_NAME}" ] && [ -f "${PRIV_KEY_NAME}" ]; then
        info "JWT keys already exist. Delete them first if you want to generate new ones."
        return 0
    elif [ -f "${PUB_KEY_NAME}" ] || [ -f "${PRIV_KEY_NAME}" ]; then
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
    openssl genpkey -algorithm RSA -out "${PRIV_KEY_NAME}" -pkeyopt rsa_keygen_bits:2048
    openssl rsa -pubout -in "${PRIV_KEY_NAME}" -out "${PUB_KEY_NAME}"
    info "JWT keys generated and saved to ${PRIV_KEY_NAME} and ${PUB_KEY_NAME} in the root directory of the project."
}
