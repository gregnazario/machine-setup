#!/usr/bin/env bash
set -euo pipefail

# Restic Backup Script
# Reads configuration from backup/restic-config.conf and performs automated backups

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${REPO_ROOT}/backup/restic-config.conf"
LOG_FILE="${HOME}/backup.log"
DRY_RUN=false
VERBOSE=false

source "${REPO_ROOT}/scripts/ini-parser.sh"

log_info() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [INFO] $1" | tee -a "$LOG_FILE"
}

log_warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [WARN] $1" | tee -a "$LOG_FILE" >&2
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [ERROR] $1" | tee -a "$LOG_FILE" >&2
}

log_success() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [SUCCESS] $1" | tee -a "$LOG_FILE"
}

check_dependencies() {
    if ! command -v restic &> /dev/null; then
        log_error "restic is not installed. Please install it first."
        exit 1
    fi
}

load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        log_error "Please create restic-config.conf with your backup settings"
        exit 1
    fi
    
    REPOSITORY=$(ini_get "$CONFIG_FILE" "repository" "location" "")
    PASSWORD=$(ini_get "$CONFIG_FILE" "repository" "password" "")
    
    # Read backup paths
    PATHS=""
    local current=1
    while true; do
        local path
        path=$(ini_get "$CONFIG_FILE" "paths" "$current" "")
        if [[ -z "$path" ]]; then
            break
        fi
        PATHS="$PATHS$path
"
        ((current++))
    done
    PATHS="${PATHS//\~/$HOME}"
    
    # Read excludes
    EXCLUDES=""
    current=1
    while true; do
        local exclude
        exclude=$(ini_get "$CONFIG_FILE" "excludes" "$current" "")
        if [[ -z "$exclude" ]]; then
            break
        fi
        EXCLUDES="$EXCLUDES$exclude
"
        ((current++))
    done
    
    # Retention policy
    KEEP_DAILY=$(ini_get "$CONFIG_FILE" "retention" "keep_daily" "7")
    KEEP_WEEKLY=$(ini_get "$CONFIG_FILE" "retention" "keep_weekly" "4")
    KEEP_MONTHLY=$(ini_get "$CONFIG_FILE" "retention" "keep_monthly" "12")
    KEEP_YEARLY=$(ini_get "$CONFIG_FILE" "retention" "keep_yearly" "2")
    
    # B2 credentials
    B2_ACCOUNT_ID=$(ini_get "$CONFIG_FILE" "b2" "account_id" "")
    B2_ACCOUNT_KEY=$(ini_get "$CONFIG_FILE" "b2" "account_key" "")
    
    # S3 credentials
    S3_ACCESS_KEY=$(ini_get "$CONFIG_FILE" "s3" "access_key" "")
    S3_SECRET_KEY=$(ini_get "$CONFIG_FILE" "s3" "secret_key" "")
    
    if [[ -z "$REPOSITORY" ]]; then
        log_error "Repository not configured in $CONFIG_FILE"
        exit 1
    fi
    
    if [[ -z "$PASSWORD" || "$PASSWORD" == "CHANGE_ME_STRONG_PASSWORD" ]]; then
        log_error "Please set a strong password in $CONFIG_FILE"
        exit 1
    fi
    
    if [[ -z "$PATHS" ]]; then
        log_error "No backup paths configured in $CONFIG_FILE"
        exit 1
    fi
}

export_credentials() {
    # Export repository password
    export RESTIC_PASSWORD="$PASSWORD"
    
    # Export B2 credentials if using B2
    if [[ "$REPOSITORY" == b2:* ]]; then
        if [[ -n "$B2_ACCOUNT_ID" && -n "$B2_ACCOUNT_KEY" ]]; then
            export B2_ACCOUNT_ID="$B2_ACCOUNT_ID"
            export B2_ACCOUNT_KEY="$B2_ACCOUNT_KEY"
        else
            log_error "B2 credentials not configured for B2 repository"
            exit 1
        fi
    fi
    
    # Export S3 credentials if using S3
    if [[ "$REPOSITORY" == s3:* ]]; then
        if [[ -n "$S3_ACCESS_KEY" && -n "$S3_SECRET_KEY" ]]; then
            export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
            export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
        else
            log_error "S3 credentials not configured for S3 repository"
            exit 1
        fi
    fi
}

init_repository() {
    log_info "Checking repository: $REPOSITORY"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would initialize repository if needed"
        return
    fi
    
    # Try to list snapshots to check if repo exists
    if ! restic snapshots &> /dev/null; then
        log_warn "Repository not initialized. Initializing..."
        if ! restic init; then
            log_error "Failed to initialize repository"
            exit 1
        fi
        log_success "Repository initialized successfully"
    else
        log_info "Repository exists and is accessible"
    fi
}

create_backup() {
    log_info "Starting backup..."
    
    # Build exclude arguments
    local exclude_args=""
    while IFS= read -r exclude; do
        if [[ -n "$exclude" ]]; then
            exclude_args="$exclude_args --exclude $exclude"
        fi
    done <<< "$EXCLUDES"
    
    # Build paths
    local backup_paths=""
    while IFS= read -r path; do
        if [[ -n "$path" ]]; then
            # Verify path exists
            if [[ ! -e "$path" ]]; then
                log_warn "Path does not exist, skipping: $path"
                continue
            fi
            backup_paths="$backup_paths $path"
        fi
    done <<< "$PATHS"
    
    if [[ -z "$backup_paths" ]]; then
        log_error "No valid paths to backup"
        exit 1
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would backup:$backup_paths"
        if [[ -n "$exclude_args" ]]; then
            log_info "[DRY-RUN] With excludes:$exclude_args"
        fi
        return
    fi
    
    # Create backup
    local backup_cmd="restic backup $backup_paths $exclude_args"
    
    if [[ "$VERBOSE" == true ]]; then
        backup_cmd="$backup_cmd --verbose"
    fi
    
    if ! $backup_cmd; then
        log_error "Backup failed"
        exit 1
    fi
    
    log_success "Backup completed successfully"
}

run_retention() {
    log_info "Applying retention policy..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would apply retention: daily=$KEEP_DAILY, weekly=$KEEP_WEEKLY, monthly=$KEEP_MONTHLY, yearly=$KEEP_YEARLY"
        return
    fi
    
    if ! restic forget \
        --keep-daily "$KEEP_DAILY" \
        --keep-weekly "$KEEP_WEEKLY" \
        --keep-monthly "$KEEP_MONTHLY" \
        --keep-yearly "$KEEP_YEARLY" \
        --prune; then
        log_error "Retention policy failed"
        exit 1
    fi
    
    log_success "Retention policy applied successfully"
}

check_backup() {
    log_info "Verifying backup integrity..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would verify backup integrity"
        return
    fi
    
    if ! restic check; then
        log_error "Backup integrity check failed"
        exit 1
    fi
    
    log_success "Backup integrity verified"
}

list_snapshots() {
    log_info "Available snapshots:"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would list snapshots"
        return
    fi
    
    restic snapshots
}

send_notification() {
    local status="$1"
    local message="$2"
    
    # Check if notify-send is available (Linux desktop)
    if command -v notify-send &> /dev/null; then
        if [[ "$status" == "success" ]]; then
            notify-send "Backup Complete" "$message" -i dialog-information
        else
            notify-send "Backup Failed" "$message" -i dialog-error
        fi
    fi
    
    # Could add email notifications here if needed
    # mail -s "Backup $status" user@example.com <<< "$message"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Restic backup script with automated scheduling support.

Options:
    -n, --dry-run          Show what would be done without executing
    -v, --verbose          Enable verbose output
    -c, --check            Run integrity check after backup
    -l, --list             List available snapshots
    -h, --help             Show this help message

Configuration:
    Configuration is read from: backup/restic-config.conf
    
    Required sections:
    - [repository]: Backup repository location and password
    - [paths]: Paths to backup (numbered entries)
    
    Optional sections:
    - [excludes]: Patterns to exclude (numbered entries)
    - [retention]: Retention policy (keep_daily, keep_weekly, etc.)
    - [b2]: B2 credentials (account_id, account_key)
    - [s3]: S3 credentials (access_key, secret_key, region)

Examples:
    $0                     # Run backup
    $0 --dry-run           # Preview backup without running
    $0 --check             # Backup and verify integrity
    $0 --list              # List snapshots
    $0 --verbose           # Run with verbose output

Cron Example:
    # Daily backup at 2 AM
    0 2 * * * /path/to/backup/backup.sh >> /var/log/backup.log 2>&1

Systemd Timer:
    See scripts/setup-backup.sh to configure automated backups
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -c|--check)
                RUN_CHECK=true
                shift
                ;;
            -l|--list)
                LIST_ONLY=true
                shift
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

main() {
    parse_args "$@"
    
    log_info "========================================="
    log_info "Restic Backup Script Started"
    log_info "========================================="
    
    check_dependencies
    load_config
    export_credentials
    
    # List mode - just list snapshots and exit
    if [[ "${LIST_ONLY:-false}" == true ]]; then
        list_snapshots
        exit 0
    fi
    
    # Initialize repository if needed
    init_repository
    
    # Create backup
    create_backup
    
    # Apply retention policy
    run_retention
    
    # Run integrity check if requested
    if [[ "${RUN_CHECK:-false}" == true ]]; then
        check_backup
    fi
    
    log_info "========================================="
    log_success "Backup process completed successfully"
    log_info "========================================="
    
    send_notification "success" "Backup completed successfully at $(date)"
}

# Run main function
main "$@"
