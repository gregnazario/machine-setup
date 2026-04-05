#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/ini-parser.sh"
source "${SCRIPT_DIR}/profile-loader.sh"

PROFILE=""
CONFLICTS=0
BROKEN=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Scan for Syncthing conflict files and broken dotfile symlinks.

Options:
    -p, --profile <name>  Profile to check (default: auto-detected)
    -h, --help            Show this help message

Examples:
    $(basename "$0") --profile minimal
    $(basename "$0") -p full
EOF
    exit 0
}

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) usage ;;
            --profile|-p) PROFILE="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    detect_platform

    if [[ -z "$PROFILE" ]]; then
        PROFILE=$(get_default_profile_for_platform)
    fi

    load_profile "$PROFILE"

    echo ""
    echo "============================================"
    echo "  Dotfile Conflict Detection: $PROFILE"
    echo "============================================"
    echo ""

    local dotfiles_source
    dotfiles_source=$(ini_get "$PROFILE_FILE" "dotfiles" "source" "")
    local dotfiles_dir="${SCRIPT_DIR}/../dotfiles/${dotfiles_source}"

    # Check for Syncthing conflict files
    log_info "Scanning for Syncthing conflicts..."
    if [[ -d "$dotfiles_dir" ]]; then
        while IFS= read -r -d '' conflict; do
            log_warn "Conflict: $conflict"
            CONFLICTS=$((CONFLICTS + 1))
        done < <(find "$dotfiles_dir" -name "*.sync-conflict-*" -print0 2>/dev/null)
    fi

    if [[ $CONFLICTS -eq 0 ]]; then
        log_success "No Syncthing conflicts found"
    fi

    # Check managed symlinks
    log_info "Checking managed symlinks..."
    local link_num=1
    while true; do
        local dest
        dest=$(ini_get "$PROFILE_FILE" "dotfiles.links.${link_num}" "dest" "")
        [[ -z "$dest" ]] && break
        dest="${dest/#\~/$HOME}"

        if [[ -L "$dest" ]]; then
            if [[ ! -e "$dest" ]]; then
                log_warn "Broken symlink: $dest -> $(readlink "$dest")"
                BROKEN=$((BROKEN + 1))
            fi
        fi

        ((link_num++))
    done

    if [[ $BROKEN -eq 0 ]]; then
        log_success "No broken symlinks found"
    fi

    # Summary
    echo ""
    echo "============================================"
    if [[ $CONFLICTS -gt 0 || $BROKEN -gt 0 ]]; then
        log_warn "Found: $CONFLICTS conflict(s), $BROKEN broken link(s)"
        return 1
    else
        log_success "No conflicts or issues detected"
        return 0
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
