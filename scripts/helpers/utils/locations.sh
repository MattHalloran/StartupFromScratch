#!/usr/bin/env bash
set -euo pipefail

_HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Common directories
export UTILS_DIR="$_HERE"
export HELPERS_DIR=$(cd "$UTILS_DIR"/.. && pwd)
export SCRIPTS_DIR=$(cd "$HELPERS_DIR"/.. && pwd)
export SCRIPT_TESTS_DIR="$SCRIPTS_DIR/__tests"
export ROOT_DIR=$(cd "$SCRIPTS_DIR"/.. && pwd)
export PACKAGES_DIR="$ROOT_DIR/packages"
export BACKUPS_DIR="$ROOT_DIR/backups"
export DATA_DIR="$ROOT_DIR/data"
export DEST_DIR="$ROOT_DIR/dist"

# Environment files
export ENV_DEV_FILE="$ROOT_DIR/.env-dev"
export ENV_PROD_FILE="$ROOT_DIR/.env-prod"

# Key pairs
export STAGING_CI_SSH_PRIV_KEY_FILE="$ROOT_DIR/ci_ssh_priv_staging.pem"
export STAGING_CI_SSH_PUB_KEY_FILE="$ROOT_DIR/ci_ssh_pub_staging.pem"
export PRODUCTION_CI_SSH_PRIV_KEY_FILE="$ROOT_DIR/ci_ssh_priv_production.pem"
export PRODUCTION_CI_SSH_PUB_KEY_FILE="$ROOT_DIR/ci_ssh_pub_production.pem"
export STAGING_JWT_PRIV_KEY_FILE="$ROOT_DIR/jwt_priv_staging.pem"
export STAGING_JWT_PUB_KEY_FILE="$ROOT_DIR/jwt_pub_staging.pem"
export PRODUCTION_JWT_PRIV_KEY_FILE="$ROOT_DIR/jwt_priv_production.pem"
export PRODUCTION_JWT_PUB_KEY_FILE="$ROOT_DIR/jwt_pub_production.pem"

# Remote server
export REMOTE_ROOT_DIR="/root/Vrooli"
export REMOTE_DIST_DIR="/var/tmp"

# Package directories/files
export POSTGRES_ENTRYPOINT_DIR="$PACKAGES_DIR/postgres/entrypoint"
export DB_SCHEMA_FILE="$PACKAGES_DIR/server/src/db/schema.prisma"