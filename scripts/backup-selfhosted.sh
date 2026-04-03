#!/usr/bin/env bash
set -euo pipefail

SELFHOSTED_DIR="${HOME}/selfhosted"
BACKUP_STAGING="${HOME}/.selfhosted-backups"
COMPOSE_FILE="${SELFHOSTED_DIR}/docker-compose.yml"

DRY_RUN=false
ACTION="backup"
STOP_SERVICES=true

log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[0;33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [ACTION]

Actions:
  backup      Export Docker volumes to staging directory (default)
  restore     Restore Docker volumes from staging directory
  list        List available volume backups
  migrate     Export volumes as portable tarballs for machine migration

Options:
  --dry-run          Show what would be done without doing it
  --no-stop          Don't stop containers during backup (risk of corruption)
  --staging DIR      Override staging directory (default: ~/.selfhosted-backups)
  --compose FILE     Override compose file path
  -h, --help         Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            backup|restore|list|migrate)
                ACTION="$1"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-stop)
                STOP_SERVICES=false
                shift
                ;;
            --staging)
                BACKUP_STAGING="$2"
                shift 2
                ;;
            --compose)
                COMPOSE_FILE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

get_compose_volumes() {
    docker compose -f "$COMPOSE_FILE" config --volumes 2>/dev/null
}

dump_postgres() {
    local container="$1"
    local user="$2"
    local dump_dir="${BACKUP_STAGING}/db-dumps"
    mkdir -p "$dump_dir"

    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        log_info "Dumping ${container} database..."
        if [[ "$DRY_RUN" == true ]]; then
            echo "  Would run: docker exec ${container} pg_dumpall -U ${user} > ${dump_dir}/${container}.sql"
            return
        fi
        docker exec "$container" pg_dumpall -U "$user" > "${dump_dir}/${container}.sql"
        log_success "${container} dump complete"
    fi
}

dump_all_databases() {
    dump_postgres "immich-postgres" "immich"
    dump_postgres "authentik-postgres" "authentik"
    dump_postgres "paperless-postgres" "paperless"
    dump_postgres "nextcloud-postgres" "nextcloud"
    dump_postgres "mealie-postgres" "mealie"
}

backup_volumes() {
    local volumes
    volumes=$(get_compose_volumes)
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="${BACKUP_STAGING}/${timestamp}"

    mkdir -p "$backup_dir"

    # Dump databases while services are running
    dump_all_databases

    # Stop services for consistent volume snapshots
    if [[ "$STOP_SERVICES" == true ]]; then
        log_info "Stopping services for consistent backup..."
        if [[ "$DRY_RUN" != true ]]; then
            docker compose -f "$COMPOSE_FILE" stop
        fi
    else
        log_warn "Backing up without stopping services — risk of data corruption"
    fi

    for volume in $volumes; do
        local project_volume
        # Docker compose prepends project name; find the actual volume
        project_volume=$(docker volume ls --format '{{.Name}}' | grep "${volume}$" | head -1)

        if [[ -z "$project_volume" ]]; then
            log_warn "Volume not found: $volume (may not exist yet)"
            continue
        fi

        log_info "Backing up volume: $project_volume"
        if [[ "$DRY_RUN" == true ]]; then
            echo "  Would export: $project_volume -> ${backup_dir}/${volume}.tar.gz"
            continue
        fi

        docker run --rm \
            -v "${project_volume}:/source:ro" \
            -v "${backup_dir}:/backup" \
            alpine tar czf "/backup/${volume}.tar.gz" -C /source .
    done

    # Copy database dumps into the timestamped backup
    if [[ -d "${BACKUP_STAGING}/db-dumps" && "$DRY_RUN" != true ]]; then
        cp -r "${BACKUP_STAGING}/db-dumps" "${backup_dir}/db-dumps"
        rm -rf "${BACKUP_STAGING}/db-dumps"
    fi

    # Copy .env and compose file for reference
    if [[ "$DRY_RUN" != true ]]; then
        cp "${SELFHOSTED_DIR}/.env" "${backup_dir}/env.backup" 2>/dev/null || true
        cp "${COMPOSE_FILE}" "${backup_dir}/docker-compose.yml.backup" 2>/dev/null || true
    fi

    # Restart services
    if [[ "$STOP_SERVICES" == true ]]; then
        log_info "Restarting services..."
        if [[ "$DRY_RUN" != true ]]; then
            docker compose -f "$COMPOSE_FILE" start
        fi
    fi

    # Clean up old staging backups (keep last 3)
    if [[ "$DRY_RUN" != true ]]; then
        local count
        count=$(ls -d "${BACKUP_STAGING}"/20* 2>/dev/null | wc -l)
        if [[ "$count" -gt 3 ]]; then
            ls -d "${BACKUP_STAGING}"/20* | head -n $((count - 3)) | xargs rm -rf
            log_info "Cleaned up old staging backups (kept last 3)"
        fi
    fi

    log_success "Backup complete: ${backup_dir}"
    log_info "This staging directory is included in your Restic backup paths"
}

restore_volumes() {
    local backup_dir
    # Use most recent backup if no specific one given
    backup_dir=$(ls -d "${BACKUP_STAGING}"/20* 2>/dev/null | tail -1)

    if [[ -z "$backup_dir" ]]; then
        log_error "No backups found in ${BACKUP_STAGING}"
        exit 1
    fi

    log_info "Restoring from: ${backup_dir}"

    # Stop services before restore
    log_info "Stopping services..."
    if [[ "$DRY_RUN" != true ]]; then
        docker compose -f "$COMPOSE_FILE" stop 2>/dev/null || true
    fi

    for archive in "${backup_dir}"/*.tar.gz; do
        local volume_name
        volume_name=$(basename "$archive" .tar.gz)

        local project_volume
        project_volume=$(docker volume ls --format '{{.Name}}' | grep "${volume_name}$" | head -1)

        # Create volume if it doesn't exist
        if [[ -z "$project_volume" ]]; then
            project_volume="selfhosted_${volume_name}"
            log_info "Creating volume: $project_volume"
            if [[ "$DRY_RUN" != true ]]; then
                docker volume create "$project_volume"
            fi
        fi

        log_info "Restoring volume: $project_volume"
        if [[ "$DRY_RUN" == true ]]; then
            echo "  Would restore: ${archive} -> $project_volume"
            continue
        fi

        docker run --rm \
            -v "${project_volume}:/dest" \
            -v "${backup_dir}:/backup:ro" \
            alpine sh -c "rm -rf /dest/* && tar xzf /backup/${volume_name}.tar.gz -C /dest"
    done

    # Restore .env if present and missing
    if [[ -f "${backup_dir}/env.backup" && ! -f "${SELFHOSTED_DIR}/.env" ]]; then
        if [[ "$DRY_RUN" != true ]]; then
            cp "${backup_dir}/env.backup" "${SELFHOSTED_DIR}/.env"
            log_info "Restored .env file"
        fi
    fi

    # Restore Postgres dumps if present
    if [[ -d "${backup_dir}/db-dumps" ]]; then
        log_info "Postgres SQL dumps available in ${backup_dir}/db-dumps/"
        log_info "To restore databases after services start:"
        for dump_file in "${backup_dir}"/db-dumps/*.sql; do
            [[ ! -f "$dump_file" ]] && continue
            local container_name
            container_name=$(basename "$dump_file" .sql)
            local db_user
            # Extract user from the container name (e.g., immich-postgres -> immich)
            db_user="${container_name%-postgres}"
            log_info "  docker exec -i ${container_name} psql -U ${db_user} < ${dump_file}"
        done
    fi

    log_info "Starting services..."
    if [[ "$DRY_RUN" != true ]]; then
        docker compose -f "$COMPOSE_FILE" up -d
    fi

    log_success "Restore complete"
}

list_backups() {
    if [[ ! -d "$BACKUP_STAGING" ]]; then
        log_info "No backups found"
        return
    fi

    log_info "Available backups in ${BACKUP_STAGING}:"
    echo ""

    for dir in "${BACKUP_STAGING}"/20*; do
        [[ ! -d "$dir" ]] && continue
        local timestamp
        timestamp=$(basename "$dir")
        local size
        size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        local archives
        archives=$(ls "$dir"/*.tar.gz 2>/dev/null | wc -l)
        echo "  ${timestamp}  ${size}  (${archives} volumes)"
    done
}

migrate_export() {
    local migrate_dir
    migrate_dir="${BACKUP_STAGING}/migrate-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$migrate_dir"

    log_info "Creating portable migration bundle..."

    # Run a full backup first
    backup_volumes

    # Copy the latest backup into the migrate dir
    local latest
    latest=$(ls -d "${BACKUP_STAGING}"/20* 2>/dev/null | tail -1)
    if [[ -n "$latest" && "$DRY_RUN" != true ]]; then
        cp -r "$latest"/* "$migrate_dir/"
    fi

    log_success "Migration bundle ready: ${migrate_dir}"
    log_info "Transfer to new machine:"
    log_info "  scp -r ${migrate_dir} newserver:~/.selfhosted-backups/$(basename "$latest")/"
    log_info "Then on new machine:"
    log_info "  ./setup.sh --profile selfhosted"
    log_info "  ./scripts/backup-selfhosted.sh restore"
}

main() {
    parse_args "$@"

    if [[ ! -f "$COMPOSE_FILE" && "$ACTION" != "list" ]]; then
        log_error "Compose file not found: $COMPOSE_FILE"
        log_info "Run './setup.sh --profile selfhosted' first"
        exit 1
    fi

    case "$ACTION" in
        backup)  backup_volumes ;;
        restore) restore_volumes ;;
        list)    list_backups ;;
        migrate) migrate_export ;;
    esac
}

main "$@"
