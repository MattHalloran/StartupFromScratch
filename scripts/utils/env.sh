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

    ENV_FILE="$ENV_PROD_FILE"
    if [ "$NODE_ENV" = "development" ]; then
        ENV_FILE="$ENV_DEV_FILE"
    fi

    if [ ! -f "$ENV_FILE" ]; then
        error "Error: Environment file $ENV_FILE does not exist."
        exit "${ERROR_ENV_FILE_MISSING}"
    fi

    info "Sourcing environment file $ENV_FILE"
    set -a
    # shellcheck source=/dev/null
    . "$ENV_FILE"
    set +a
}

# Load secrets from a vault
load_vault_secrets() {
    #TODO
    echo "TODO"
}

load_secrets() {
    header "🔑 Loading secrets..."

    : "${SECRETS_SOURCE:?Required environment variable SECRETS_SOURCE is not set}"
    : "${ENVIRONMENT:?Required environment variable ENVIRONMENT is not set}"
   
    NODE_ENV="${NODE_ENV:-development}"
    case "$ENVIRONMENT" in
        [dD]*) NODE_ENV="development" ;;
        [pP]*) NODE_ENV="production" ;;
        *) error "Invalid environment: $ENVIRONMENT"
            exit "${ERROR_USAGE}"
            ;;
    esac

    case "$SECRETS_SOURCE" in
        e|env|environment|f|file) load_env_file ;;
        v|vault|hashicorp|hashicorp-vault) load_vault_secrets ;;
        *) error "Invalid secrets source: $SECRETS_SOURCE"
            exit "${ERROR_USAGE}"
            ;;
    esac

    export NODE_ENV
    export DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@db:${PORT_DB:-5432}"
    export REDIS_URL="redis://:${REDIS_PASSWORD}@redis:${PORT_REDIS:-6379}"
}

is_running_in_ci() {
    [[ "$CI" == "true" ]]
}
