#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/yaml-parser.sh"

CONFIG_FILE="${SCRIPT_DIR}/../backup/restic-config.yaml"
BACKUP_SCRIPT="${SCRIPT_DIR}/../backup/backup.sh"

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

check_restic_installed() {
    if ! command -v restic &> /dev/null; then
        log_error "Restic is not installed. Please install it first."
        exit 1
    fi
}

create_config_template() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_warn "Backup config already exists at $CONFIG_FILE"
        return
    fi
    
    log_info "Creating backup configuration template..."
    
    cat > "$CONFIG_FILE" <<EOF
# Restic Backup Configuration
# Edit this file with your backup settings

# Repository location
# For BackBlaze B2:
repository: b2:your-bucket-name:machine-backup
# For S3:
# repository: s3:s3.amazonaws.com/your-bucket-name/machine-backup

# Repository password (use a strong password!)
# Store this in a password manager!
password: ""

# Backup schedule
schedule: daily

# Retention policy
retention:
  keep-daily: 7
  keep-weekly: 4
  keep-monthly: 12
  keep-yearly: 2

# Paths to backup
paths:
  - ~/dotfiles
  - ~/.ssh
  - ~/Documents
  - ~/Projects

# Paths to exclude
excludes:
  - node_modules
  - .git/objects
  - "*.log"
  - "*.tmp"
  - __pycache__
  - .cache
  - "*.pyc"

# B2/S3 credentials (if using B2 or S3)
# Store these in a password manager!
b2:
  account_id: ""
  account_key: ""

s3:
  access_key: ""
  secret_key: ""
EOF
    
    log_success "Created backup config template at $CONFIG_FILE"
    log_warn "Please edit $CONFIG_FILE with your backup settings"
}

create_backup_script() {
    log_info "Creating backup script..."
    
    cat > "$BACKUP_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/restic-config.yaml"

source "${REPO_ROOT}/scripts/yaml-parser.sh"

DRY_RUN=false

log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        exit 1
    fi
    
    local config_content=$(cat "$CONFIG_FILE")
    
    REPOSITORY=$(yaml_get "$config_content" "repository" "")
    PASSWORD=$(yaml_get "$config_content" "password" "")
    
    export RESTIC_REPOSITORY="$REPOSITORY"
    export RESTIC_PASSWORD="$PASSWORD"
    
    B2_ACCOUNT_ID=$(yaml_get "$config_content" "b2.account_id" "")
    B2_ACCOUNT_KEY=$(yaml_get "$config_content" "b2.account_key" "")
    
    if [[ -n "$B2_ACCOUNT_ID" && -n "$B2_ACCOUNT_KEY" ]]; then
        export B2_ACCOUNT_ID
        export B2_ACCOUNT_KEY
    fi
}

run_backup() {
    local config_content=$(cat "$CONFIG_FILE")
    local paths=$(yaml_get_list "$config_content" "paths")
    local excludes=$(yaml_get_list "$config_content" "excludes")
    
    local exclude_args=""
    while IFS= read -r exclude; do
        [[ -n "$exclude" ]] && exclude_args="$exclude_args --exclude $exclude"
    done <<< "$excludes"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Dry run - would backup:"
        echo "Paths: $paths"
        echo "Excludes: $excludes"
        return
    fi
    
    log_info "Starting backup..."
    
    restic backup $paths $exclude_args
    
    log_success "Backup complete!"
    
    log_info "Running retention policy..."
    local keep_daily=$(yaml_get "$config_content" "retention.keep-daily" "7")
    local keep_weekly=$(yaml_get "$config_content" "retention.keep-weekly" "4")
    local keep_monthly=$(yaml_get "$config_content" "retention.keep-monthly" "12")
    
    restic forget \
        --keep-daily "$keep_daily" \
        --keep-weekly "$keep_weekly" \
        --keep-monthly "$keep_monthly" \
        --prune
    
    log_success "Retention policy applied"
}

main() {
    parse_args "$@"
    load_config
    run_backup
}

main "$@"
EOF
    
    chmod +x "$BACKUP_SCRIPT"
    log_success "Created backup script at $BACKUP_SCRIPT"
}

setup_cron_job() {
    detect_platform
    
    log_info "Setting up daily backup cron job..."
    
    if [[ "$PLATFORM" == "macos" ]]; then
        log_info "On macOS, use launchd instead of cron"
        log_info "Create a launchd plist in ~/Library/LaunchAgents/"
        return
    fi
    
    local cron_job="0 2 * * * ${BACKUP_SCRIPT} >> ~/backup.log 2>&1"
    
    log_info "Add this line to your crontab (crontab -e):"
    echo "$cron_job"
}

setup_systemd_timer() {
    detect_platform
    
    if [[ "$PLATFORM" != "fedora" && "$PLATFORM" != "ubuntu" && "$PLATFORM" != "raspberrypios" ]]; then
        log_info "Systemd timers not available on this platform"
        return
    fi
    
    log_info "Creating systemd timer for daily backups..."
    
    local service_file="$HOME/.config/systemd/user/restic-backup.service"
    local timer_file="$HOME/.config/systemd/user/restic-backup.timer"
    
    mkdir -p "$(dirname "$service_file")"
    
    cat > "$service_file" <<EOF
[Unit]
Description=Restic Backup

[Service]
Type=oneshot
ExecStart=${BACKUP_SCRIPT}
EOF
    
    cat > "$timer_file" <<EOF
[Unit]
Description=Daily Restic Backup

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    systemctl --user daemon-reload
    systemctl --user enable restic-backup.timer
    systemctl --user start restic-backup.timer
    
    log_success "Systemd timer created and enabled"
}

main() {
    detect_platform
    log_info "Setting up backup for platform: $PLATFORM"
    
    check_restic_installed
    create_config_template
    create_backup_script
    
    read -p "Setup automated daily backups? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        if [[ "$PLATFORM" == "fedora" || "$PLATFORM" == "ubuntu" || "$PLATFORM" == "raspberrypios" ]]; then
            setup_systemd_timer
        else
            setup_cron_job
        fi
    fi
    
    log_success "Backup setup complete!"
    log_info "Next steps:"
    echo "  1. Edit $CONFIG_FILE with your backup settings"
    echo "  2. Test backup: $BACKUP_SCRIPT --dry-run"
    echo "  3. Run initial backup: $BACKUP_SCRIPT"
}

main "$@"
