#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/ini-parser.sh"
source "${SCRIPT_DIR}/profile-loader.sh"
source "${SCRIPT_DIR}/install-packages.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

diff_arrays() {
    local label="$1"
    shift
    local -a items_a=()
    local -a items_b=()
    local collecting_a=true

    for item in "$@"; do
        if [[ "$item" == "---" ]]; then
            collecting_a=false
            continue
        fi
        if [[ "$collecting_a" == true ]]; then
            items_a+=("$item")
        else
            items_b+=("$item")
        fi
    done

    echo -e "\n${CYAN}${label}:${NC}"

    # Find items only in A, only in B, in both
    local -a only_a=() only_b=() both=()
    for item in "${items_a[@]}"; do
        local found=false
        for b_item in "${items_b[@]}"; do
            if [[ "$item" == "$b_item" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == true ]]; then
            both+=("$item")
        else
            only_a+=("$item")
        fi
    done
    for item in "${items_b[@]}"; do
        local found=false
        for a_item in "${items_a[@]}"; do
            if [[ "$item" == "$a_item" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" != true ]]; then
            only_b+=("$item")
        fi
    done

    for item in "${only_a[@]}"; do
        echo -e "  ${RED}- ${item}${NC}"
    done
    for item in "${only_b[@]}"; do
        echo -e "  ${GREEN}+ ${item}${NC}"
    done
    for item in "${both[@]}"; do
        echo "    ${item}"
    done

    if [[ ${#only_a[@]} -eq 0 && ${#only_b[@]} -eq 0 ]]; then
        echo "  (identical)"
    fi
}

main() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <profile-a> <profile-b>"
        exit 1
    fi

    local profile_a="$1"
    local profile_b="$2"

    detect_platform

    echo ""
    echo "============================================"
    echo "  Profile Diff: $profile_a vs $profile_b"
    echo "============================================"
    echo ""
    echo -e "Legend: ${RED}- only in ${profile_a}${NC}  ${GREEN}+ only in ${profile_b}${NC}  (unchanged)"

    # Load profile A packages
    load_profile "$profile_a"
    local pkgs_a
    pkgs_a=$(collect_packages | tr ' ' '\n' | sort -u)

    local services_a
    services_a=$(get_profile_services | sort -u)

    local dotfiles_a=()
    local link_num=1
    while true; do
        local dest
        dest=$(ini_get "$PROFILE_FILE" "dotfiles.links.${link_num}" "dest" "")
        [[ -z "$dest" ]] && break
        dotfiles_a+=("$dest")
        ((link_num++))
    done

    # Load profile B packages
    load_profile "$profile_b"
    local pkgs_b
    pkgs_b=$(collect_packages | tr ' ' '\n' | sort -u)

    local services_b
    services_b=$(get_profile_services | sort -u)

    local dotfiles_b=()
    link_num=1
    while true; do
        local dest
        dest=$(ini_get "$PROFILE_FILE" "dotfiles.links.${link_num}" "dest" "")
        [[ -z "$dest" ]] && break
        dotfiles_b+=("$dest")
        ((link_num++))
    done

    # Diff packages
    # shellcheck disable=SC2086
    diff_arrays "Packages" $pkgs_a "---" $pkgs_b

    # Diff dotfiles
    diff_arrays "Dotfile Links" "${dotfiles_a[@]}" "---" "${dotfiles_b[@]}"

    # Diff services
    # shellcheck disable=SC2086
    diff_arrays "Services" $services_a "---" $services_b

    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
