#!/usr/bin/env bash
# Audit logging for machine-setup
# Source this file to add audit logging to any script.

AUDIT_LOG="${MACHINE_SETUP_DIR:-$HOME/.machine-setup}/audit.log"

audit_log() {
    local action="$1"
    local detail="${2:-}"
    local status="${3:-info}"

    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local platform="${PLATFORM:-unknown}"
    local profile="${PROFILE:-unknown}"
    local user
    user="$(whoami)"
    local hostname_val
    hostname_val="$(hostname -s 2>/dev/null || echo unknown)"

    # Ensure log directory exists
    mkdir -p "$(dirname "$AUDIT_LOG")"

    # Append to log (tab-separated for easy parsing)
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$timestamp" "$status" "$action" "$profile" "$platform" "$user" "$hostname_val" "$detail" \
        >> "$AUDIT_LOG"
}

audit_setup_start() {
    audit_log "setup-start" "args: $*" "info"
}

audit_setup_complete() {
    audit_log "setup-complete" "${1:-}" "success"
}

audit_setup_failed() {
    audit_log "setup-failed" "${1:-}" "error"
}

audit_action() {
    audit_log "$1" "${2:-}" "info"
}

# Show recent audit log entries
audit_show() {
    local count="${1:-20}"

    if [[ ! -f "$AUDIT_LOG" ]]; then
        echo "No audit log found at $AUDIT_LOG"
        return 0
    fi

    echo ""
    printf "  %-22s %-8s %-18s %-10s %-10s %-10s %s\n" \
        "TIMESTAMP" "STATUS" "ACTION" "PROFILE" "PLATFORM" "USER" "DETAIL"
    printf "  %-22s %-8s %-18s %-10s %-10s %-10s %s\n" \
        "---------" "------" "------" "-------" "--------" "----" "------"

    tail -n "$count" "$AUDIT_LOG" | while IFS=$'\t' read -r ts status action profile platform user _host detail; do
        printf "  %-22s %-8s %-18s %-10s %-10s %-10s %s\n" \
            "$ts" "$status" "$action" "$profile" "$platform" "$user" "$detail"
    done
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        show) audit_show "${2:-20}" ;;
        *) echo "Usage: $0 show [count]" ;;
    esac
fi
