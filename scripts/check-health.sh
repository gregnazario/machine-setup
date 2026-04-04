#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/ini-parser.sh"
source "${SCRIPT_DIR}/profile-loader.sh"

WARNINGS=0
ERRORS=0

warn() {
    log_warn "$1"
    ((WARNINGS++)) || true
}

error() {
    log_error "$1"
    ((ERRORS++)) || true
}

check_commands() {
    log_info "Checking key binaries..."
    local cmds=(git nvim nu rg fd fzf)
    for cmd in "${cmds[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            log_success "  $cmd: $(command -v "$cmd")"
        else
            warn "  $cmd: not found on PATH"
        fi
    done
}

check_dotfile_links() {
    log_info "Checking dotfile symlinks..."
    local link_num=1
    while true; do
        local src dest
        src=$(ini_get "$PROFILE_FILE" "dotfiles.links.${link_num}" "src" "")
        dest=$(ini_get "$PROFILE_FILE" "dotfiles.links.${link_num}" "dest" "")

        if [[ -z "$src" || -z "$dest" ]]; then
            break
        fi

        # Expand ~ in dest
        dest="${dest/#\~/$HOME}"

        if [[ -L "$dest" ]]; then
            local target
            target=$(readlink "$dest")
            log_success "  $dest -> $target"
        elif [[ -e "$dest" ]]; then
            warn "  $dest exists but is not a symlink"
        else
            error "  $dest does not exist"
        fi

        ((link_num++))
    done

    if [[ $link_num -eq 1 ]]; then
        log_info "  No dotfile links configured."
    fi
}

check_services() {
    log_info "Checking services..."
    local services
    services=$(get_profile_services)

    if [[ -z "$services" ]]; then
        log_info "  No services configured."
        return
    fi

    while IFS= read -r service; do
        [[ -z "$service" ]] && continue
        case "$service" in
            docker)
                if docker info &>/dev/null 2>&1; then
                    log_success "  docker: running"
                else
                    warn "  docker: not running or not accessible"
                fi
                ;;
            *)
                if pgrep -x "$service" &>/dev/null; then
                    log_success "  $service: running"
                else
                    warn "  $service: not running"
                fi
                ;;
        esac
    done <<< "$services"
}

main() {
    local profile=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--profile)
                profile="$2"
                shift 2
                ;;
            *)
                echo "Usage: $0 --profile <name>"
                exit 1
                ;;
        esac
    done

    if [[ -z "$profile" ]]; then
        echo "Error: --profile is required"
        echo "Usage: $0 --profile <name>"
        exit 1
    fi

    detect_platform
    load_profile "$profile"

    echo "============================================"
    echo "Health Check: $profile on $PLATFORM"
    echo "============================================"
    echo

    check_commands
    echo
    check_dotfile_links
    echo
    check_services
    echo

    echo "============================================"
    echo "Summary: $WARNINGS warning(s), $ERRORS error(s)"
    echo "============================================"

    if [[ $ERRORS -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
