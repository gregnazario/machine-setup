#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/profile-loader.sh"
source "${SCRIPT_DIR}/yaml-parser.sh"

PROFILE=""
DRY_RUN=false
FORCE=false

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

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

backup_existing() {
    local target="$1"
    
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ "$FORCE" == true ]]; then
            log_warn "Removing existing: $target"
            rm -rf "$target"
        else
            local backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"
            log_warn "Backing up existing: $target -> $backup"
            mv "$target" "$backup"
        fi
    fi
}

create_symlink() {
    local source="$1"
    local target="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would create symlink: $target -> $source"
        return
    fi
    
    backup_existing "$target"
    
    local target_dir=$(dirname "$target")
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
    fi
    
    ln -s "$source" "$target"
    log_success "Created symlink: $target -> $source"
}

link_dotfiles() {
    local dotfiles_config=$(get_profile_dotfiles)
    local dotfiles_source=$(yaml_get "$dotfiles_config" "source" "")
    local dotfiles_dir="${SCRIPT_DIR}/../dotfiles/${dotfiles_source}"
    
    if [[ ! -d "$dotfiles_dir" ]]; then
        log_error "Dotfiles directory not found: $dotfiles_dir"
        exit 1
    fi
    
    log_info "Linking dotfiles from: $dotfiles_dir"
    
    local links=$(yaml_get_objects "$dotfiles_config" "links")
    
    while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        
        local src=$(yaml_object_get "$link" "src")
        local dest=$(yaml_object_get "$link" "dest")
        
        src="${src/#\~/$HOME}"
        dest="${dest/#\~/$HOME}"
        
        local full_source="${dotfiles_dir}/${src}"
        local full_target="$dest"
        
        if [[ -e "$full_source" ]]; then
            create_symlink "$full_source" "$full_target"
        else
            log_warn "Source not found: $full_source"
        fi
    done <<< "$links"
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
    
    link_dotfiles
    
    log_success "Dotfiles linked successfully!"
}

main "$@"
