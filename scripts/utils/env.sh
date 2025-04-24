#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$HERE"/../.. && pwd)
ENV_DEV_FILE="$ROOT_DIR/.env-dev"
ENV_PROD_FILE="$ROOT_DIR/.env-prod"

# shellcheck disable=SC1091
source "${HERE}/../utils/logging.sh"
# shellcheck disable=SC1091
source "${HERE}/../utils/exit_codes.sh"

# Load secrets from an environment file
load_env_file() {

    ENV_FILE=""
    case "$ENVIRONMENT" in
        [dD]*) ENV_FILE="$ENV_DEV_FILE" ;;
        [pP]*) ENV_FILE="$ENV_PROD_FILE" ;;
        *) error "Invalid environment: $ENVIRONMENT"
            exit "${ERROR_USAGE}"
            ;;
    esac

    if [ ! -f "$ENV_FILE" ]; then
        error "Error: Environment file $ENV_FILE does not exist."
        exit "${ERROR_ENV_FILE_MISSING}"
    fi

    info "Sourcing environment file $ENV_FILE"
    # shellcheck source=/dev/null
    . "$ENV_FILE"
}

# Load secrets from a vault
load_vault_secrets() {
    #TODO
    echo "TODO"
}

load_secrets() {
    header "🔑 Loading secrets..."

    : "${SECRETS_SOURCE:?Required environment variable SECRETS_SOURCE is not set}"

    case "$SECRETS_SOURCE" in
        e|env|environment|f|file) load_env_file ;;
        v|vault|hashicorp|hashicorp-vault) load_vault_secrets ;;
        *) error "Invalid secrets source: $SECRETS_SOURCE"
            exit "${ERROR_USAGE}"
            ;;
    esac
}

is_running_in_ci() {
    [[ "$CI" == "true" ]]
}
