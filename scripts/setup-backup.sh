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

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Create a backup configuration template and set up automated backups
using restic.

Options:
    -h, --help    Show this help message
EOF
    exit 0
}

main() {
    case "${1:-}" in
        -h|--help) usage ;;
    esac

    detect_platform
    log_info "Setting up backup for platform: $PLATFORM"
    
    check_restic_installed
    create_config_template
    
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
