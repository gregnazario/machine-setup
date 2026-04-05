#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/profile-loader.sh"
source "${SCRIPT_DIR}/ini-parser.sh"

PROFILE=""
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Remove managed dotfile symlinks created by link-dotfiles.sh.

Options:
    --profile <name>  Profile to use (default: auto-detected)
    --dry-run         Show what would be removed without making changes
    -h, --help        Show this help message

Examples:
    $(basename "$0") --profile minimal
    $(basename "$0") --dry-run
EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            --profile)
                PROFILE="$2"
                shift 2
                ;;
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

remove_symlink() {
    local target="$1"
    local dotfiles_dir="$2"

    if [[ ! -L "$target" ]]; then
        return 0
    fi

    local link_dest
    link_dest="$(readlink "$target")"

    case "$link_dest" in
        "${dotfiles_dir}"/*)
            if [[ "$DRY_RUN" == true ]]; then
                echo "Would remove symlink: $target"
                return 0
            fi
            rm "$target"
            log_success "Removed symlink: $target"
            ;;
        *)
            log_info "Skipping (not managed): $target -> $link_dest"
            ;;
    esac
}

unlink_dotfiles() {
    local dotfiles_source
    dotfiles_source=$(ini_get "$PROFILE_FILE" "dotfiles" "source" "")
    local dotfiles_dir="${SCRIPT_DIR}/../dotfiles/${dotfiles_source}"

    if [[ ! -d "$dotfiles_dir" ]]; then
        log_error "Dotfiles directory not found: $dotfiles_dir"
        exit 1
    fi

    # Resolve to absolute path for comparison
    dotfiles_dir="$(cd "$dotfiles_dir" && pwd)"

    log_info "Unlinking dotfiles managed by: $dotfiles_dir"

    local current_link=1
    while true; do
        local dest
        dest=$(ini_get "$PROFILE_FILE" "dotfiles.links.${current_link}" "dest" "")

        if [[ -z "$dest" ]]; then
            break
        fi

        dest="${dest/#\~/$HOME}"

        remove_symlink "$dest" "$dotfiles_dir"

        ((current_link++))
    done
}

main() {
    parse_args "$@"

    detect_platform
    log_info "Detected platform: $PLATFORM"

    if [[ -z "$PROFILE" ]]; then
        PROFILE=$(get_default_profile_for_platform)
        log_info "Using default profile: $PROFILE"
    fi

    load_profile "$PROFILE"
    log_info "Using profile: $PROFILE"

    unlink_dotfiles

    log_success "Dotfile symlinks removed successfully!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
