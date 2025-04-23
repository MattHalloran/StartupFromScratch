#!/usr/bin/env bash

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$HERE"/../.. && pwd)
source "${HERE}/../utils/logging.sh"

load_env_file() {
    info "Loading environment variables for $ENVIRONMENT..."

    HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

    local environment=$1
    local env_file="$ROOT_DIR/.env-dev"

    if [ "$environment" != "development" ] && [ "$environment" != "production" ]; then
        error "Error: Environment must be either development or production."
        exit ${ERROR_USAGE}
    fi

    if [ "$environment" = "production" ]; then
        env_file="$ROOT_DIR/.env-prod"
    fi

    if [ ! -f "$env_file" ]; then
        error "Error: Environment file $env_file does not exist."
        exit ${ERROR_ENV_FILE_MISSING}
    fi

    . "$env_file"
}

is_running_in_ci() {
    [[ "$CI" == "true" ]]
}