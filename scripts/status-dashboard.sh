#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/ini-parser.sh"
source "${SCRIPT_DIR}/profile-loader.sh"

PROFILE=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile|-p)
                PROFILE="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
}

section() {
    echo ""
    echo -e "\033[1m$1\033[0m"
    echo "────────────────────────────────────"
}

status_platform() {
    section "Platform"
    echo "  OS:              $PLATFORM"
    echo "  Package Manager: $PACKAGE_MANAGER"
    echo "  Profile:         $PROFILE"
    echo "  Shell:           ${SHELL:-unknown}"
    echo "  Home:            $HOME"
}

status_packages() {
    section "Key Packages"
    local cmds=("git" "nvim" "nu" "rg" "fd:fdfind" "fzf")
    for entry in "${cmds[@]}"; do
        local cmd="${entry%%:*}"
        local alt="${entry#*:}"
        if command -v "$cmd" &>/dev/null; then
            local ver
            ver=$("$cmd" --version 2>/dev/null | head -1) || ver="installed"
            echo "  $cmd: $ver"
        elif [[ "$alt" != "$cmd" ]] && command -v "$alt" &>/dev/null; then
            local ver
            ver=$("$alt" --version 2>/dev/null | head -1) || ver="installed"
            echo "  $alt: $ver"
        else
            echo "  $cmd: not installed"
        fi
    done
}

status_dotfiles() {
    section "Dotfile Links"
    local linked=0 missing=0 broken=0
    local current_link=1
    while true; do
        local dest
        dest=$(ini_get "$PROFILE_FILE" "dotfiles.links.${current_link}" "dest" "")
        [[ -z "$dest" ]] && break
        dest="${dest/#\~/$HOME}"

        if [[ -L "$dest" ]]; then
            if [[ -e "$dest" ]]; then
                linked=$((linked + 1))
            else
                broken=$((broken + 1))
            fi
        elif [[ -e "$dest" ]]; then
            missing=$((missing + 1))  # exists but not a symlink
        else
            missing=$((missing + 1))
        fi
        ((current_link++))
    done
    local total=$((current_link - 1))
    echo "  Linked:  $linked / $total"
    if [[ $broken -gt 0 ]]; then
        echo "  Broken:  $broken"
    fi
    if [[ $missing -gt 0 ]]; then
        echo "  Missing: $missing"
    fi
    if [[ $linked -eq $total && $total -gt 0 ]]; then
        echo "  Status:  all good"
    fi
}

status_git_crypt() {
    section "Git-Crypt"
    local repo_dir="${SCRIPT_DIR}/.."
    if [[ -f "$repo_dir/dotfiles/.gitattributes" ]]; then
        if command -v git-crypt &>/dev/null; then
            # Check if repo is unlocked by trying to read an encrypted file
            if git -C "$repo_dir" crypt status &>/dev/null 2>&1; then
                echo "  Status:  unlocked"
            else
                echo "  Status:  locked (run: git-crypt unlock)"
            fi
        else
            echo "  Status:  git-crypt not installed"
        fi
    else
        echo "  Status:  not configured"
    fi
}

status_syncthing() {
    section "Syncthing"
    if command -v syncthing &>/dev/null; then
        if pgrep -x syncthing &>/dev/null; then
            echo "  Status:  running"
            # Try to get version
            local ver
            ver=$(syncthing --version 2>/dev/null | head -1) || ver=""
            [[ -n "$ver" ]] && echo "  Version: $ver"
        else
            echo "  Status:  installed but not running"
        fi
    else
        echo "  Status:  not installed"
    fi
}

status_backup() {
    section "Backup (Restic)"
    local config="${SCRIPT_DIR}/../backup/restic-config.conf"
    if command -v restic &>/dev/null; then
        if [[ -f "$config" ]]; then
            local repo
            repo=$(ini_get "$config" "repository" "location" "")
            local password
            password=$(ini_get "$config" "repository" "password" "")
            if [[ -n "$repo" && "$password" != "CHANGE_ME_STRONG_PASSWORD" ]]; then
                echo "  Repo:    $repo"
                echo "  Config:  configured"
            else
                echo "  Config:  needs setup (edit backup/restic-config.conf)"
            fi
        else
            echo "  Config:  not found"
        fi

        local ver
        ver=$(restic version 2>/dev/null) || ver=""
        [[ -n "$ver" ]] && echo "  Version: $ver"
    else
        echo "  Status:  restic not installed"
    fi
}

status_services() {
    section "Services"
    local services
    services=$(get_profile_services)

    if [[ -z "$services" ]]; then
        echo "  No services configured"
        return
    fi

    while IFS= read -r service; do
        [[ -z "$service" ]] && continue
        case "$service" in
            docker)
                if docker info &>/dev/null 2>&1; then
                    echo "  docker:    running"
                else
                    echo "  docker:    not running"
                fi
                ;;
            *)
                if pgrep -x "$service" &>/dev/null; then
                    echo "  $service:  running"
                else
                    echo "  $service:  not running"
                fi
                ;;
        esac
    done <<< "$services"
}

main() {
    parse_args "$@"
    detect_platform

    if [[ -z "$PROFILE" ]]; then
        PROFILE=$(get_default_profile_for_platform)
    fi

    load_profile "$PROFILE"

    echo ""
    echo "============================================"
    echo "  Machine Setup Status Dashboard"
    echo "============================================"

    status_platform
    status_packages
    status_dotfiles
    status_git_crypt
    status_syncthing
    status_backup
    status_services

    echo ""
    echo "============================================"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
