#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/ini-parser.sh"
source "${SCRIPT_DIR}/profile-loader.sh"
source "${SCRIPT_DIR}/install-packages.sh"

# Color variables
GREEN='\033[0;32m'
# shellcheck disable=SC2034
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PROFILE=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
}

# Map package name to the command it provides
package_to_command() {
    local pkg="$1"
    case "$pkg" in
        neovim) echo "nvim" ;;
        nushell) echo "nu" ;;
        ripgrep) echo "rg" ;;
        fd-find) echo "fd" ;;
        python3) echo "python3" ;;
        gh) echo "gh" ;;
        *) echo "$pkg" ;;
    esac
}

diff_packages() {
    echo -e "\n${CYAN}Packages:${NC}"
    local packages
    packages=$(collect_packages)

    for pkg in $packages; do
        local cmd
        cmd=$(package_to_command "$pkg")
        if command -v "$cmd" &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} ${pkg}"
        else
            echo -e "  ${CYAN}+${NC} ${pkg}"
        fi
    done
}

diff_dotfiles() {
    echo -e "\n${CYAN}Dotfiles:${NC}"
    local dotfiles_source
    dotfiles_source=$(ini_get "$PROFILE_FILE" "dotfiles" "source" "")
    local dotfiles_dir="${SCRIPT_DIR}/../dotfiles/${dotfiles_source}"

    local current_link=1
    while true; do
        local src dest
        src=$(ini_get "$PROFILE_FILE" "dotfiles.links.${current_link}" "src" "")
        dest=$(ini_get "$PROFILE_FILE" "dotfiles.links.${current_link}" "dest" "")

        if [[ -z "$src" || -z "$dest" ]]; then
            break
        fi

        dest="${dest/#\~/$HOME}"
        local full_source="${dotfiles_dir}/${src}"

        if [[ -L "$dest" ]]; then
            local link_target
            link_target=$(readlink "$dest")
            if [[ "$link_target" == "$full_source" ]]; then
                echo -e "  ${GREEN}✓${NC} ${dest}"
            else
                echo -e "  ${YELLOW}~${NC} ${dest} (points to ${link_target})"
            fi
        elif [[ -e "$dest" ]]; then
            echo -e "  ${YELLOW}~${NC} ${dest} (exists but not a symlink)"
        else
            echo -e "  ${CYAN}+${NC} ${dest}"
        fi

        ((current_link++))
    done
}

main() {
    parse_args "$@"

    detect_platform

    if [[ -z "$PROFILE" ]]; then
        PROFILE=$(get_default_profile_for_platform)
    fi

    load_profile "$PROFILE"

    echo ""
    echo "=== Dry-Run Diff: $PROFILE ==="
    echo ""
    echo -e "Legend: ${GREEN}✓${NC} installed/linked  ${CYAN}+${NC} would install/link  ${YELLOW}~${NC} exists (conflict)"

    diff_packages
    diff_dotfiles

    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
