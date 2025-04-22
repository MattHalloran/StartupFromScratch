HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${HERE}/../utils/logging.sh"

load_env_file() {
    HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

    local environment=$1
    local env_file="$HERE/../.env-dev"

    if [ "$environment" != "development" ] && [ "$environment" != "production" ]; then
        error "Error: Environment must be either development or production."
        exit ${ERROR_USAGE}
    fi

    if [ "$environment" = "production" ]; then
        env_file="$HERE/../.env-prod"
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