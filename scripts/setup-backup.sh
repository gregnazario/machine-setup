#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/ini-parser.sh"

CONFIG_FILE="${SCRIPT_DIR}/../backup/restic-config.conf"
BACKUP_SCRIPT="${SCRIPT_DIR}/../backup/backup.sh"

source "${SCRIPT_DIR}/lib/common.sh"

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
# Copy this file and fill in your credentials
# This file will be encrypted by git-crypt

[repository]
location = b2:your-bucket-name:machine-backup
password = CHANGE_ME_STRONG_PASSWORD

[backup]
schedule = daily

[retention]
keep_daily = 7
keep_weekly = 4
keep_monthly = 12
keep_yearly = 2

[paths]
1 = ~/dotfiles
2 = ~/.ssh
3 = ~/Documents
4 = ~/Projects

[excludes]
1 = node_modules
2 = .git/objects
3 = *.log
4 = *.tmp
5 = __pycache__
6 = .cache
7 = *.pyc

[b2]
account_id = YOUR_B2_ACCOUNT_ID
account_key = YOUR_B2_ACCOUNT_KEY

[s3]
access_key = YOUR_S3_ACCESS_KEY
secret_key = YOUR_S3_SECRET_KEY
region = us-east-1
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
CONFIG_FILE="${SCRIPT_DIR}/restic-config.conf"

source "${REPO_ROOT}/scripts/ini-parser.sh"

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
    
    REPOSITORY=$(ini_get "$CONFIG_FILE" "repository" "location" "")
    PASSWORD=$(ini_get "$CONFIG_FILE" "repository" "password" "")
    
    export RESTIC_REPOSITORY="$REPOSITORY"
    export RESTIC_PASSWORD="$PASSWORD"
    
    B2_ACCOUNT_ID=$(ini_get "$CONFIG_FILE" "b2" "account_id" "")
    B2_ACCOUNT_KEY=$(ini_get "$CONFIG_FILE" "b2" "account_key" "")
    
    if [[ -n "$B2_ACCOUNT_ID" && -n "$B2_ACCOUNT_KEY" ]]; then
        export B2_ACCOUNT_ID
        export B2_ACCOUNT_KEY
    fi
}

run_backup() {
    local paths=""
    local current_path=1
    while true; do
        local path=$(ini_get "$CONFIG_FILE" "paths" "$current_path" "")
        if [[ -z "$path" ]]; then
            break
        fi
        paths="$paths $path"
        ((current_path++))
    done
    paths=$(echo "$paths" | xargs)
    
    local excludes=""
    local current_exclude=1
    while true; do
        local exclude=$(ini_get "$CONFIG_FILE" "excludes" "$current_exclude" "")
        if [[ -z "$exclude" ]]; then
            break
        fi
        excludes="$excludes --exclude $exclude"
        ((current_exclude++))
    done
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Dry run - would backup:"
        echo "Paths: $paths"
        echo "Excludes: $excludes"
        return
    fi
    
    log_info "Starting backup..."
    
    restic backup $paths $excludes
    
    log_success "Backup complete!"
    
    log_info "Running retention policy..."
    local keep_daily=$(ini_get "$CONFIG_FILE" "retention" "keep_daily" "7")
    local keep_weekly=$(ini_get "$CONFIG_FILE" "retention" "keep_weekly" "4")
    local keep_monthly=$(ini_get "$CONFIG_FILE" "retention" "keep_monthly" "12")
    
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

setup_launchd_plist() {
    local plist_src="${SCRIPT_DIR}/../backup/com.user.restic-backup.plist"
    local plist_dest="$HOME/Library/LaunchAgents/com.user.restic-backup.plist"

    if [[ ! -f "$plist_src" ]]; then
        log_warn "launchd plist template not found at $plist_src"
        setup_cron_job
        return
    fi

    mkdir -p "$HOME/Library/LaunchAgents"
    cp "$plist_src" "$plist_dest"
    launchctl load "$plist_dest" 2>/dev/null || true
    log_success "launchd plist installed at $plist_dest"
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
    
    local systemd_platforms="fedora ubuntu debian raspberrypios arch opensuse rocky alma"
    if ! echo "$systemd_platforms" | grep -qw "$PLATFORM"; then
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
        local systemd_platforms="fedora ubuntu debian raspberrypios arch opensuse rocky alma"
        if echo "$systemd_platforms" | grep -qw "$PLATFORM"; then
            setup_systemd_timer
        elif [[ "$PLATFORM" == "macos" ]]; then
            setup_launchd_plist
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
