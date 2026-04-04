#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/ini-parser.sh"

REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${REPO_DIR}/backup/restic-config.conf"
MAX_AGE_DAYS="${BACKUP_MAX_AGE_DAYS:-7}"

notify_failure() {
    local message="$1"
    if command -v notify-send &>/dev/null; then
        notify-send -u critical "Backup Verification Failed" "$message"
    elif command -v osascript &>/dev/null; then
        osascript -e "display notification \"$message\" with title \"Backup Verification Failed\" sound name \"Basso\""
    fi
    log_error "$message"
}

main() {
    log_info "Verifying backup integrity..."

    if [[ ! -f "$CONFIG_FILE" ]]; then
        notify_failure "Backup config not found: $CONFIG_FILE"
        exit 1
    fi

    # Load restic config
    local repo password
    repo=$(ini_get "$CONFIG_FILE" "repository" "location" "")
    password=$(ini_get "$CONFIG_FILE" "repository" "password" "")

    if [[ -z "$repo" || "$password" == "CHANGE_ME_STRONG_PASSWORD" ]]; then
        notify_failure "Backup not configured (placeholder credentials)"
        exit 1
    fi

    export RESTIC_REPOSITORY="$repo"
    export RESTIC_PASSWORD="$password"

    # Load B2/S3 credentials
    local b2_id b2_key
    b2_id=$(ini_get "$CONFIG_FILE" "b2" "account_id" "")
    b2_key=$(ini_get "$CONFIG_FILE" "b2" "account_key" "")
    if [[ -n "$b2_id" && -n "$b2_key" ]]; then
        export B2_ACCOUNT_ID="$b2_id"
        export B2_ACCOUNT_KEY="$b2_key"
    fi

    if ! command -v restic &>/dev/null; then
        notify_failure "restic not installed"
        exit 1
    fi

    # Check repository integrity
    log_info "Running integrity check..."
    if ! restic check 2>&1; then
        notify_failure "Backup integrity check failed for $repo"
        exit 1
    fi
    log_success "Integrity check passed"

    # Check last snapshot age
    log_info "Checking last snapshot..."
    local last_snapshot
    last_snapshot=$(restic snapshots --json --latest 1 2>/dev/null | grep -o '"time":"[^"]*"' | head -1 | sed 's/"time":"//;s/"//')

    if [[ -z "$last_snapshot" ]]; then
        notify_failure "No snapshots found in $repo"
        exit 1
    fi

    log_info "Last snapshot: $last_snapshot"

    # Check if snapshot is too old (platform-compatible date comparison)
    local now_epoch snapshot_epoch
    now_epoch=$(date +%s)
    snapshot_epoch=$(date -d "$last_snapshot" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "${last_snapshot%%.*}" +%s 2>/dev/null || echo 0)

    if [[ "$snapshot_epoch" -gt 0 ]]; then
        local age_days=$(( (now_epoch - snapshot_epoch) / 86400 ))
        if [[ "$age_days" -gt "$MAX_AGE_DAYS" ]]; then
            notify_failure "Last backup is $age_days days old (threshold: $MAX_AGE_DAYS days)"
            exit 1
        fi
        log_success "Last backup is $age_days day(s) old (within $MAX_AGE_DAYS day threshold)"
    fi

    log_success "Backup verification passed"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
