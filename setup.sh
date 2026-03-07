#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/platform-detect.sh"
source "${SCRIPT_DIR}/scripts/profile-loader.sh"

DEFAULT_PROFILE="auto"
PROFILE="${DEFAULT_PROFILE}"
INSTALL_PACKAGES=true
LINK_DOTFILES=true
SETUP_SYNCTHING=true
SETUP_BACKUP=true
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Cross-platform machine setup with profile-based configuration.

Options:
    -p, --profile <name>     Profile to use (minimal, full, or custom profile)
                             Default: auto (minimal on RaspberryPiOS, full elsewhere)
    --no-packages            Skip package installation
    --no-dotfiles            Skip dotfile linking
    --no-syncthing           Skip Syncthing setup
    --no-backup              Skip backup setup
    --dry-run                Show what would be done without executing
    --list-profiles          List available profiles
    --show-profile <name>    Show details of a specific profile
    -h, --help               Show this help message

Examples:
    $0                                 # Auto-detect profile
    $0 --profile minimal               # Use minimal profile
    $0 --profile full --no-backup      # Full profile, skip backup
    $0 --list-profiles                 # List all profiles

Supported Platforms:
    - Fedora (dnf)
    - Ubuntu (apt)
    - Gentoo (emerge)
    - Void Linux (xbps)
    - RaspberryPiOS (apt)
    - macOS (homebrew)
    - FreeBSD (pkg)
    - Windows 11 (winget)
EOF
}

list_profiles() {
    echo "Available profiles:"
    echo
    for profile_file in "${SCRIPT_DIR}/profiles"/*.yaml; do
        if [[ -f "$profile_file" ]]; then
            local profile_name=$(basename "$profile_file" .yaml)
            local description=$(grep "^description:" "$profile_file" | cut -d' ' -f2-)
            printf "  %-15s %s\n" "$profile_name" "$description"
        fi
    done
    echo
    echo "Note: Files ending in .example are templates, not active profiles."
}

show_profile() {
    local profile_name="$1"
    local profile_file="${SCRIPT_DIR}/profiles/${profile_name}.yaml"
    
    if [[ ! -f "$profile_file" ]]; then
        echo "Error: Profile '$profile_name' not found."
        exit 1
    fi
    
    echo "Profile: $profile_name"
    echo
    cat "$profile_file"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--profile)
                PROFILE="$2"
                shift 2
                ;;
            --no-packages)
                INSTALL_PACKAGES=false
                shift
                ;;
            --no-dotfiles)
                LINK_DOTFILES=false
                shift
                ;;
            --no-syncthing)
                SETUP_SYNCTHING=false
                shift
                ;;
            --no-backup)
                SETUP_BACKUP=false
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --list-profiles)
                list_profiles
                exit 0
                ;;
            --show-profile)
                show_profile "$2"
                exit 0
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Error: Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v git &> /dev/null; then
        log_error "git is not installed. Please install git first."
        exit 1
    fi
    
    if ! command -v yq &> /dev/null; then
        log_warn "yq is not installed. Installing..."
        if [[ "$PLATFORM" == "macos" ]]; then
            brew install yq
        elif [[ "$PLATFORM" != "windows" ]]; then
            curl -sL https://github.com/mikefarah/yq/releases/download/v4.35.1/yq_linux_amd64 -o /tmp/yq
            chmod +x /tmp/yq
            sudo mv /tmp/yq /usr/local/bin/yq
        fi
    fi
}

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

main() {
    parse_args "$@"
    
    log_info "Starting machine setup..."
    
    detect_platform
    log_info "Detected platform: $PLATFORM"
    
    if [[ "$PROFILE" == "auto" ]]; then
        PROFILE=$(get_default_profile_for_platform)
        log_info "Auto-detected profile: $PROFILE"
    fi
    
    load_profile "$PROFILE"
    log_info "Using profile: $PROFILE"
    
    check_prerequisites
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "DRY RUN MODE - No changes will be made"
    fi
    
    if [[ "$INSTALL_PACKAGES" == true ]]; then
        log_info "Installing packages..."
        if [[ "$DRY_RUN" == false ]]; then
            "${SCRIPT_DIR}/scripts/install-packages.sh" --profile "$PROFILE"
        else
            echo "  Would install packages for profile: $PROFILE"
        fi
    fi
    
    if [[ "$LINK_DOTFILES" == true ]]; then
        log_info "Linking dotfiles..."
        if [[ "$DRY_RUN" == false ]]; then
            "${SCRIPT_DIR}/scripts/link-dotfiles.sh" --profile "$PROFILE"
        else
            echo "  Would link dotfiles for profile: $PROFILE"
        fi
    fi
    
    if [[ "$SETUP_SYNCTHING" == true ]]; then
        log_info "Setting up Syncthing..."
        if [[ "$DRY_RUN" == false ]]; then
            "${SCRIPT_DIR}/scripts/setup-syncthing.sh"
        else
            echo "  Would setup Syncthing"
        fi
    fi
    
    if [[ "$SETUP_BACKUP" == true ]]; then
        log_info "Setting up backup..."
        if [[ "$DRY_RUN" == false ]]; then
            "${SCRIPT_DIR}/scripts/setup-backup.sh"
        else
            echo "  Would setup backup with Restic"
        fi
    fi
    
    log_success "Setup complete!"
    
    if [[ "$PLATFORM" != "windows" ]]; then
        log_info "Next steps:"
        echo "  1. Unlock git-crypt: git-crypt unlock"
        echo "  2. Start Syncthing: syncthing (or enable service)"
        echo "  3. Verify backup: ${SCRIPT_DIR}/backup/backup.sh --dry-run"
    fi
}

main "$@"
