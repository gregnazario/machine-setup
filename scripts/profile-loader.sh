#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/yaml-parser.sh"

PROFILE_NAME=""
PROFILE_DATA=""

log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

load_profile() {
    local profile_name="$1"
    local profile_file="${SCRIPT_DIR}/../profiles/${profile_name}.yaml"
    local extends
    
    if [[ ! -f "$profile_file" ]]; then
        log_error "Profile file not found: $profile_file"
        exit 1
    fi
    
    PROFILE_NAME="$profile_name"
    
    extends=$(grep "^extends:" "$profile_file" | awk '{print $2}')
    
    if [[ -n "$extends" && "$extends" != "null" ]]; then
        log_info "Profile extends: $extends"
        local base_profile_data
        local current_profile_data
        base_profile_data=$(load_profile_yaml "$extends")
        current_profile_data=$(cat "$profile_file")
        PROFILE_DATA=$(merge_profiles "$base_profile_data" "$current_profile_data")
    else
        PROFILE_DATA=$(cat "$profile_file")
    fi
    
    export PROFILE_NAME PROFILE_DATA
}

load_profile_yaml() {
    local profile_name="$1"
    local profile_file="${SCRIPT_DIR}/../profiles/${profile_name}.yaml"
    
    if [[ ! -f "$profile_file" ]]; then
        log_error "Base profile not found: $profile_name"
        exit 1
    fi
    
    local extends=$(grep "^extends:" "$profile_file" | awk '{print $2}')
    
    if [[ -n "$extends" && "$extends" != "null" ]]; then
        local base_data=$(load_profile_yaml "$extends")
        local current_data=$(cat "$profile_file")
        merge_profiles "$base_data" "$current_data"
    else
        cat "$profile_file"
    fi
}

merge_profiles() {
    local base_data="$1"
    local overlay_data="$2"
    
    yaml_merge "$base_data" "$overlay_data"
}

get_profile_packages() {
    local packages_yaml=$(echo "$PROFILE_DATA" | _yaml_extract_section_stdin "packages")
    echo "$packages_yaml"
}

_yaml_extract_section_stdin() {
    local section_name="$1"
    
    local in_section=false
    local section_depth=0
    local section_content=""
    
    while IFS= read -r line; do
        local stripped="${line#"${line%%[![:space:]]*}"}"
        local leading_spaces=$((${#line} - ${#stripped}))
        local line_depth=$((leading_spaces / 2))
        
        if [[ "$stripped" =~ ^${section_name}:[[:space:]]*(.*)$ ]]; then
            in_section=true
            section_depth=$line_depth
            local value="${BASH_REMATCH[1]}"
            if [[ -n "$value" && "$value" != "null" ]]; then
                echo "$line"
                return
            fi
            continue
        fi
        
        if [[ $in_section == true ]]; then
            if [[ $line_depth -gt $section_depth ]]; then
                section_content="$section_content$line
"
            else
                break
            fi
        fi
    done
    
    if [[ -n "$section_content" ]]; then
        echo "${section_name}:"
        echo -n "$section_content"
    fi
}

get_profile_dotfiles() {
    local dotfiles_yaml=$(echo "$PROFILE_DATA" | _yaml_extract_section_stdin "dotfiles")
    echo "$dotfiles_yaml"
}

get_profile_services() {
    yaml_get_list "$PROFILE_DATA" "services"
}

get_profile_scripts() {
    yaml_get_list "$PROFILE_DATA" "setup_scripts"
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
