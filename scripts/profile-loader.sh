#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-detect.sh"

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
    
    if [[ ! -f "$profile_file" ]]; then
        log_error "Profile file not found: $profile_file"
        exit 1
    fi
    
    PROFILE_NAME="$profile_name"
    
    local extends=$(grep "^extends:" "$profile_file" | awk '{print $2}')
    
    if [[ -n "$extends" && "$extends" != "null" ]]; then
        log_info "Profile extends: $extends"
        local base_profile_data=$(load_profile_yaml "$extends")
        local current_profile_data=$(cat "$profile_file")
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
    
    echo "$base_data" > /tmp/base_profile.yaml
    echo "$overlay_data" > /tmp/overlay_profile.yaml
    
    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
        /tmp/base_profile.yaml /tmp/overlay_profile.yaml
    
    rm -f /tmp/base_profile.yaml /tmp/overlay_profile.yaml
}

get_profile_packages() {
    echo "$PROFILE_DATA" | yq eval '.packages' -
}

get_profile_dotfiles() {
    echo "$PROFILE_DATA" | yq eval '.dotfiles' -
}

get_profile_services() {
    echo "$PROFILE_DATA" | yq eval '.services[]?' -
}

get_profile_scripts() {
    echo "$PROFILE_DATA" | yq eval '.setup_scripts[]?' -
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
