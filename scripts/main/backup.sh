#!/usr/bin/env bash
# This script periodically backs up the database and essential files from a remote server
set -euo pipefail

MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/env.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/locations.sh"
# shellcheck disable=SC1091
source "${MAIN_DIR}/../helpers/utils/log.sh"

# Default values
BACKUP_COUNT="5"

do_backup() {
    if [ -z "$SITE_IP" ]; then
        echo "Error: SITE_IP not set in environment"
        exit $ERROR_USAGE
    fi

    # Set the remote server location, using SITE_IP from .env
    remote_server="root@${SITE_IP}"
    log::info "Remote server: ${remote_server}"

    # Fetch the version number from the package.json on the remote server
    VERSION=$(ssh -i ~/.ssh/id_rsa_${SITE_IP} $remote_server "cat ${REMOTE_ROOT_DIR}/package.json | grep '\"version\":' | head -1 | awk -F: '{ print \$2 }' | sed 's/[\", ]//g'")
    log::info "Version number retrieved from remote package.json: ${VERSION}"

    # Set the local directory to save the backup files to
    backup_root_dir="${BACKUPS_DIR}/${SITE_IP}"
    local_dir="${backup_root_dir}/$(date +"%Y%m%d%H%M%S")"

    # Create the backup directory
    mkdir -p "${local_dir}"

    # Backup the database, data directory, JWT files, and .env* files
    ssh -i ~/.ssh/id_rsa_${SITE_IP} $remote_server "cd ${REMOTE_ROOT_DIR} && tar -czf - data/postgres-prod jwt_* .env*" >"${local_dir}/backup-$VERSION.tar.gz"

    # Remove old backup directories to keep only the most recent k backups
    ls -t "$backup_root_dir" | tail -n +$((BACKUP_COUNT + 1)) | xargs -I {} rm -r "$backup_root_dir"/{}

    # Log the backup operation
    log::info "Backup created: ${local_dir}/backup-$VERSION.tar.gz"
}

init_backup() {
    export NODE_ENV="${NODE_ENV:-production}"
    env::load_env_file

    "${HERE}/keylessSsh.sh"
}

schedule_backups() {
    init_backup

    LOG_DIR="${ROOT_DIR}/data"
    mkdir -p "${LOG_DIR}"

    # Define cron schedule and command
    CRON_SCHEDULE="@daily"
    # CRON_CMD="${HERE}/backup.sh"
    CRON_CMD="${HERE}/backup.sh run_backup"
    # Cron entry: append stdout to backup.log and stderr to backup.err
    CRON_ENTRY="${CRON_SCHEDULE} ${CRON_CMD} >>\\"${LOG_DIR}/backup.log\\" 2>>\\"${LOG_DIR}/backup.err\\""

    # Install cron entry if not already present
    if crontab -l 2>/dev/null | grep -F "${CRON_CMD}" >/dev/null; then
        log::info "Backup cron already installed"
    else
        (crontab -l 2>/dev/null; echo "${CRON_ENTRY}") | crontab -
        log::success "✅ Scheduled backup cron job: ${CRON_ENTRY}"
    fi

    # Start a backup immediately
    do_backup
}

main() {
    if [[ "${1:-}" == "run_backup" ]]; then
        do_backup
    else
        schedule_backups
    fi
}

main "$@"
