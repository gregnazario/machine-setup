#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/ini-parser.sh"

# Only initialize if not already set (e.g., when sourced)
PROFILE_NAME="${PROFILE_NAME:-}"
PROFILE_FILE="${PROFILE_FILE:-}"

source "${SCRIPT_DIR}/lib/common.sh"

load_profile() {
    local profile_name="$1"
    local profile_path="${SCRIPT_DIR}/../profiles/${profile_name}.conf"
    
    if [[ ! -f "$profile_path" ]]; then
        log_error "Profile file not found: $profile_path"
        exit 1
    fi
    
    PROFILE_NAME="$profile_name"
    PROFILE_FILE="$profile_path"
    
    local extends
    extends=$(ini_get "$PROFILE_FILE" "profile" "extends" "false")
    
    if [[ -n "$extends" && "$extends" != "false" ]]; then
        log_info "Profile extends: $extends"
        local base_profile
        base_profile="${SCRIPT_DIR}/../profiles/${extends}.conf"
        
        if [[ ! -f "$base_profile" ]]; then
            log_error "Base profile not found: $base_profile"
            exit 1
        fi
        
        # Merge profiles (overlay takes precedence)
        local tmp_profile
        tmp_profile=$(mktemp)
        ini_merge "$base_profile" "$PROFILE_FILE" "$tmp_profile"
        PROFILE_FILE="$tmp_profile"
    fi
    
    export PROFILE_NAME PROFILE_FILE
}

get_profile_packages() {
    local packages=""
    local in_packages=false

    while IFS= read -r line; do
        # Section header
        if [[ "$line" =~ ^\[([^]]+)\] ]]; then
            if [[ "${BASH_REMATCH[1]}" == "packages" ]]; then
                in_packages=true
            else
                in_packages=false
            fi
            continue
        fi

        # Package entries
        if [[ "$in_packages" == true && "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local pkgs="${BASH_REMATCH[2]}"
            packages="$packages$pkgs
"
        fi
    done < "$PROFILE_FILE"
    
    echo "$packages"
}

get_profile_dotfiles() {
    local dotfiles_source
    dotfiles_source=$(ini_get "$PROFILE_FILE" "dotfiles" "source" "")
    echo "source: $dotfiles_source"
    
    # Get dotfile links
    local current_link=1
    while true; do
        local src
        local dest
        src=$(ini_get "$PROFILE_FILE" "dotfiles.links.${current_link}" "src" "")
        dest=$(ini_get "$PROFILE_FILE" "dotfiles.links.${current_link}" "dest" "")
        
        if [[ -z "$src" || -z "$dest" ]]; then
            break
        fi
        
        echo "link: $src -> $dest"
        ((current_link++))
    done
}

get_profile_services() {
    ini_get_list "$PROFILE_FILE" "services" "enable"
}

get_profile_scripts() {
    ini_get_list "$PROFILE_FILE" "setup_scripts" "run"
}

get_default_profile_for_platform() {
    detect_platform
    
    case "$PLATFORM" in
        raspberrypios)
            echo "minimal"
            ;;
        *)
            echo "full"
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <profile-name>"
        exit 1
    fi
    
    load_profile "$1"
    echo "Profile: $PROFILE_NAME"
    echo
    echo "Packages:"
    get_profile_packages
    echo
    echo "Services:"
    get_profile_services
fi
