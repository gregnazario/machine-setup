#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/ini-parser.sh"

FLEET_FILE="${MACHINE_SETUP_DIR:-$HOME/.machine-setup}/fleet.conf"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ensure_fleet_file() {
    local dir
    dir="$(dirname "$FLEET_FILE")"
    mkdir -p "$dir"
    if [[ ! -f "$FLEET_FILE" ]]; then
        echo "# Machine Setup Fleet Registry" > "$FLEET_FILE"
        echo "# Tracks machines managed by machine-setup" >> "$FLEET_FILE"
    fi
}

fleet_register() {
    local name="$1"
    local host="$2"
    local profile="${3:-full}"

    ensure_fleet_file

    if grep -q "^\[machine\.${name}\]" "$FLEET_FILE" 2>/dev/null; then
        log_warn "Machine '$name' already registered. Updating..."
        # Remove old entry
        fleet_remove "$name"
    fi

    cat >> "$FLEET_FILE" <<EOF

[machine.${name}]
host = ${host}
profile = ${profile}
registered = $(date -u +%Y-%m-%dT%H:%M:%S)
last_setup = never
status = registered
EOF

    log_success "Registered machine: $name ($host) with profile: $profile"
}

fleet_remove() {
    local name="$1"
    ensure_fleet_file

    if ! grep -q "^\[machine\.${name}\]" "$FLEET_FILE" 2>/dev/null; then
        log_error "Machine '$name' not found in fleet"
        return 1
    fi

    # Remove the section (from [machine.name] to next [machine. or EOF)
    local tmp
    tmp="$(mktemp)"
    awk -v name="$name" '
        /^\[machine\./ { skip = ($0 == "[machine." name "]") }
        !skip { print }
    ' "$FLEET_FILE" > "$tmp"
    mv "$tmp" "$FLEET_FILE"

    log_success "Removed machine: $name"
}

fleet_list() {
    ensure_fleet_file

    local machines=()
    while IFS= read -r section; do
        if [[ "$section" == machine.* ]]; then
            machines+=("${section#machine.}")
        fi
    done < <(ini_get_sections "$FLEET_FILE")

    if [[ ${#machines[@]} -eq 0 ]]; then
        log_info "No machines registered. Use: fleet register <name> <host>"
        return 0
    fi

    echo ""
    printf "  %-15s %-25s %-12s %-20s %s\n" "NAME" "HOST" "PROFILE" "LAST SETUP" "STATUS"
    printf "  %-15s %-25s %-12s %-20s %s\n" "----" "----" "-------" "----------" "------"

    for name in "${machines[@]}"; do
        local host profile last_setup status
        host=$(ini_get "$FLEET_FILE" "machine.${name}" "host" "unknown")
        profile=$(ini_get "$FLEET_FILE" "machine.${name}" "profile" "unknown")
        last_setup=$(ini_get "$FLEET_FILE" "machine.${name}" "last_setup" "never")
        status=$(ini_get "$FLEET_FILE" "machine.${name}" "status" "unknown")

        printf "  %-15s %-25s %-12s %-20s %s\n" "$name" "$host" "$profile" "$last_setup" "$status"
    done
    echo ""
}

fleet_setup() {
    local name="$1"
    ensure_fleet_file

    local host profile
    host=$(ini_get "$FLEET_FILE" "machine.${name}" "host" "")
    profile=$(ini_get "$FLEET_FILE" "machine.${name}" "profile" "full")

    if [[ -z "$host" ]]; then
        log_error "Machine '$name' not found in fleet"
        return 1
    fi

    log_info "Setting up machine: $name ($host) with profile: $profile"

    if bash "${REPO_DIR}/scripts/remote-setup.sh" "$host" --profile "$profile"; then
        # Update fleet status
        local tmp
        tmp="$(mktemp)"
        local ts
        ts="$(date -u +%Y-%m-%dT%H:%M:%S)"
        sed "s/^\(last_setup = \).*/\1${ts}/" "$FLEET_FILE" | \
            sed "/^\[machine\.${name}\]/,/^\[/ s/^\(status = \).*/\1ok/" > "$tmp"
        mv "$tmp" "$FLEET_FILE"
        log_success "Machine $name setup complete"
    else
        local tmp
        tmp="$(mktemp)"
        sed "/^\[machine\.${name}\]/,/^\[/ s/^\(status = \).*/\1failed/" "$FLEET_FILE" > "$tmp"
        mv "$tmp" "$FLEET_FILE"
        log_error "Machine $name setup failed"
        return 1
    fi
}

fleet_setup_all() {
    ensure_fleet_file
    local machines=()
    while IFS= read -r section; do
        if [[ "$section" == machine.* ]]; then
            machines+=("${section#machine.}")
        fi
    done < <(ini_get_sections "$FLEET_FILE")

    if [[ ${#machines[@]} -eq 0 ]]; then
        log_info "No machines registered"
        return 0
    fi

    local succeeded=0 failed=0
    for name in "${machines[@]}"; do
        if fleet_setup "$name"; then
            succeeded=$((succeeded + 1))
        else
            failed=$((failed + 1))
        fi
    done

    echo ""
    log_info "Fleet setup: $succeeded succeeded, $failed failed out of ${#machines[@]}"
    [[ $failed -eq 0 ]]
}

main() {
    local action="${1:-}"
    shift || true

    case "$action" in
        register)
            local name="${1:-}" host="${2:-}" profile="full"
            shift 2 || { echo "Usage: $0 register <name> <user@host> [--profile <p>]"; exit 1; }
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --profile|-p) profile="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            fleet_register "$name" "$host" "$profile"
            ;;
        remove)
            fleet_remove "${1:?Usage: $0 remove <name>}"
            ;;
        list)
            fleet_list
            ;;
        setup)
            fleet_setup "${1:?Usage: $0 setup <name>}"
            ;;
        setup-all)
            fleet_setup_all
            ;;
        *)
            echo "Usage: $0 <register|remove|list|setup|setup-all>"
            echo ""
            echo "Commands:"
            echo "  register <name> <host> [--profile <p>]  Register a machine"
            echo "  remove <name>                           Remove a machine"
            echo "  list                                    List all machines"
            echo "  setup <name>                            Run setup on a machine"
            echo "  setup-all                               Run setup on all machines"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
