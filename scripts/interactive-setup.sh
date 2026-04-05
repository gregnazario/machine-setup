#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/ini-parser.sh"

REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
BOLD='\033[1m'
NC='\033[0m'

prompt_yes_no() {
    local question="$1"
    local default="${2:-y}"
    local hint="[Y/n]"
    [[ "$default" == "n" ]] && hint="[y/N]"

    while true; do
        echo -en "${BOLD}${question}${NC} ${hint} "
        read -r answer
        answer="${answer:-$default}"
        case "$answer" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

prompt_choice() {
    local question="$1"
    shift
    local options=("$@")

    echo -e "\n${BOLD}${question}${NC}"
    local i=1
    for opt in "${options[@]}"; do
        echo "  $i) $opt"
        i=$((i + 1))
    done

    while true; do
        echo -en "Choice [1-${#options[@]}]: "
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#options[@]} ]]; then
            return $((choice - 1))
        fi
        echo "Please enter a number between 1 and ${#options[@]}."
    done
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Interactive wizard that guides you through machine setup, including
profile selection, component choices, and optional dry run.

Options:
    -h, --help    Show this help message
EOF
    exit 0
}

main() {
    case "${1:-}" in
        -h|--help) usage ;;
    esac

    detect_platform

    echo ""
    echo "============================================"
    echo "  Machine Setup - Interactive Wizard"
    echo "============================================"
    echo ""
    log_info "Detected platform: $PLATFORM ($PACKAGE_MANAGER)"
    echo ""

    # Step 1: Choose profile
    local profiles=()
    local profile_descriptions=()
    for conf in "$REPO_DIR"/profiles/*.conf; do
        [[ -f "$conf" ]] || continue
        local name desc
        name=$(basename "$conf" .conf)
        desc=$(ini_get "$conf" "profile" "description" "")
        profiles+=("$name")
        profile_descriptions+=("$name - $desc")
    done

    prompt_choice "Select a profile:" "${profile_descriptions[@]}"
    local profile_idx=$?
    local selected_profile="${profiles[$profile_idx]}"
    log_success "Selected profile: $selected_profile"

    # Step 2: Choose components
    local setup_args=("--profile" "$selected_profile")

    echo ""
    if ! prompt_yes_no "Install packages?"; then
        setup_args+=("--no-packages")
    fi

    if ! prompt_yes_no "Link dotfiles?"; then
        setup_args+=("--no-dotfiles")
    fi

    if ! prompt_yes_no "Setup Syncthing sync?" "n"; then
        setup_args+=("--no-syncthing")
    fi

    if ! prompt_yes_no "Setup automated backups?" "n"; then
        setup_args+=("--no-backup")
    fi

    # Step 3: Dry run first?
    echo ""
    if prompt_yes_no "Do a dry run first (recommended)?"; then
        echo ""
        log_info "Running dry-run preview..."
        echo ""
        bash "${REPO_DIR}/setup.sh" "${setup_args[@]}" --dry-run
        echo ""
        if ! prompt_yes_no "Proceed with actual setup?"; then
            log_info "Aborted. Run again when ready."
            exit 0
        fi
    fi

    # Step 4: Run setup
    echo ""
    log_info "Running setup..."
    echo ""
    exec bash "${REPO_DIR}/setup.sh" "${setup_args[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
