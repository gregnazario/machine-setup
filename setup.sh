#!/usr/bin/env bash
set -euo pipefail

# Machine Setup - Cross-platform configuration and syncing
# Can be run standalone: curl -fsSL https://raw.githubusercontent.com/yourusername/machine-setup/main/setup.sh | bash
# Or from within the cloned repo: ./setup.sh

REPO_URL="${MACHINE_SETUP_REPO:-https://github.com/yourusername/machine-setup.git}"
INSTALL_DIR="${MACHINE_SETUP_DIR:-$HOME/.machine-setup}"

DEFAULT_PROFILE="auto"
PROFILE="${DEFAULT_PROFILE}"
INSTALL_PACKAGES=true
LINK_DOTFILES=true
SETUP_SYNCTHING=true
SETUP_BACKUP=true
DRY_RUN=false

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
    --validate-profile <name>  Validate a profile's configuration
    --create-profile <name>  Create a new profile from template
    --unlink                 Remove dotfile symlinks (use with --profile)
    --check                  Check health of current setup (use with --profile)
    --status                 Show status dashboard of current setup
    -i, --interactive        Interactive setup wizard
    -h, --help               Show this help message

Environment Variables:
    MACHINE_SETUP_REPO       Git repository URL (default: $REPO_URL)
    MACHINE_SETUP_DIR        Local install directory (default: $INSTALL_DIR)

Examples:
    $0                                 # Auto-detect profile
    $0 --profile minimal               # Use minimal profile
    $0 --profile full --no-backup      # Full profile, skip backup
    $0 --list-profiles                 # List all profiles

Supported Platforms:
    - Fedora (dnf)
    - Ubuntu (apt)
    - Debian (apt)
    - Gentoo (emerge)
    - Void Linux (xbps)
    - Arch Linux (pacman)
    - Alpine Linux (apk)
    - NixOS (nix)
    - OpenSUSE (zypper)
    - Rocky Linux (dnf)
    - AlmaLinux (dnf)
    - RaspberryPiOS (apt)
    - macOS (homebrew)
    - FreeBSD (pkg)
    - Windows 11 (winget)
    - WSL2 (apt)
    - ChromeOS (apt)
    - Termux (pkg)
EOF
}

# Bootstrap: ensure we're running from within the repo
ensure_repo() {
    # Check if we're already inside the repo
    if [[ -f "${SCRIPT_DIR}/scripts/platform-detect.sh" && -f "${SCRIPT_DIR}/scripts/profile-loader.sh" ]]; then
        REPO_DIR="$SCRIPT_DIR"
        return 0
    fi

    # Not inside the repo — clone it
    log_info "Repo not found locally. Cloning from ${REPO_URL}..."

    if ! command -v git &> /dev/null; then
        log_error "git is required to bootstrap. Please install git first."
        exit 1
    fi

    if [[ -d "$INSTALL_DIR/.git" ]]; then
        log_info "Updating existing clone at ${INSTALL_DIR}..."
        git -C "$INSTALL_DIR" pull --ff-only || {
            log_warn "Pull failed, re-cloning..."
            rm -rf "$INSTALL_DIR"
            git clone "$REPO_URL" "$INSTALL_DIR"
        }
    else
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi

    REPO_DIR="$INSTALL_DIR"
    log_success "Repository ready at ${REPO_DIR}"
}

list_profiles() {
    echo "Available profiles:"
    echo
    for profile_file in "${REPO_DIR}/profiles"/*.conf; do
        if [[ -f "$profile_file" ]]; then
            local profile_name
            profile_name=$(basename "$profile_file" .conf)
            source "${REPO_DIR}/scripts/ini-parser.sh"
            local description
            description=$(ini_get "$profile_file" "profile" "description" "")
            printf "  %-15s %s\n" "$profile_name" "$description"
        fi
    done
    echo
    echo "Note: Files ending in .example are templates, not active profiles."
}

show_profile() {
    local profile_name="$1"
    local profile_file="${REPO_DIR}/profiles/${profile_name}.conf"

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
                # Need repo first for listing
                SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                ensure_repo
                source "${REPO_DIR}/scripts/ini-parser.sh"
                list_profiles
                exit 0
                ;;
            --show-profile)
                SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                ensure_repo
                show_profile "$2"
                exit 0
                ;;
            --validate-profile)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --validate-profile requires a profile name"
                    exit 1
                fi
                SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                ensure_repo
                bash "${REPO_DIR}/scripts/validate-profile.sh" --profile "$2"
                exit $?
                ;;
            --unlink)
                SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                ensure_repo
                shift
                bash "${REPO_DIR}/scripts/unlink-dotfiles.sh" "$@"
                exit $?
                ;;
            --check)
                SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                ensure_repo
                shift
                bash "${REPO_DIR}/scripts/check-health.sh" "$@"
                exit $?
                ;;
            --create-profile)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --create-profile requires a profile name"
                    exit 1
                fi
                local new_profile="$2"
                # Validate profile name to prevent path traversal
                if [[ "$new_profile" =~ [/\\] || "$new_profile" == *..* || ! "$new_profile" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                    echo "Error: Invalid profile name '$new_profile' (only alphanumeric, hyphens, underscores allowed)"
                    exit 1
                fi
                SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                ensure_repo
                local profile_path="${REPO_DIR}/profiles/${new_profile}.conf"
                if [[ -f "$profile_path" ]]; then
                    echo "Error: Profile '$new_profile' already exists at $profile_path"
                    exit 1
                fi
                cat > "$profile_path" <<PROFILE_EOF
# Profile: ${new_profile}
# Created: $(date +%Y-%m-%d)

[profile]
name = ${new_profile}
description = Custom profile
extends = minimal

[packages]
# Add packages here, e.g.:
# tools = jq httpie

[dotfiles]
source = profiles/minimal/

[services]
# enable = sshd

[setup_scripts]
# run = scripts/setup-ssh-agent.sh
PROFILE_EOF
                echo "Created profile: $profile_path"
                echo "Edit it to customize, then run: $0 --validate-profile $new_profile"
                exit 0
                ;;
            --status)
                SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                ensure_repo
                shift
                bash "${REPO_DIR}/scripts/status-dashboard.sh" "$@"
                exit $?
                ;;
            --interactive|-i)
                SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                ensure_repo
                bash "${REPO_DIR}/scripts/interactive-setup.sh"
                exit $?
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
}

main() {
    # Fast-path: --help needs nothing sourced
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            usage
            exit 0
        fi
    done

    parse_args "$@"

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    log_info "Starting machine setup..."

    ensure_repo

    source "${REPO_DIR}/scripts/lib/common.sh"

    source "${REPO_DIR}/scripts/platform-detect.sh"
    source "${REPO_DIR}/scripts/profile-loader.sh"

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
            bash "${REPO_DIR}/scripts/install-packages.sh" --profile "$PROFILE"
        fi
    fi

    if [[ "$LINK_DOTFILES" == true ]]; then
        log_info "Linking dotfiles..."
        if [[ "$DRY_RUN" == false ]]; then
            bash "${REPO_DIR}/scripts/link-dotfiles.sh" --profile "$PROFILE"
        fi
    fi

    if [[ "$SETUP_SYNCTHING" == true ]]; then
        log_info "Setting up Syncthing..."
        if [[ "$DRY_RUN" == false ]]; then
            bash "${REPO_DIR}/scripts/setup-syncthing.sh"
        else
            echo "  Would setup Syncthing"
        fi
    fi

    if [[ "$SETUP_BACKUP" == true ]]; then
        log_info "Setting up backup..."
        if [[ "$DRY_RUN" == false ]]; then
            bash "${REPO_DIR}/scripts/setup-backup.sh"
        else
            echo "  Would setup backup with Restic"
        fi
    fi

    if [[ "$DRY_RUN" == true ]]; then
        bash "${REPO_DIR}/scripts/dry-run-diff.sh" --profile "$PROFILE"
    fi

    log_success "Setup complete!"

    if [[ "$PLATFORM" != "windows" ]]; then
        log_info "Next steps:"
        echo "  1. Unlock git-crypt: git-crypt unlock"
        echo "  2. Start Syncthing: syncthing (or enable service)"
        echo "  3. Verify backup: ${REPO_DIR}/backup/backup.sh --dry-run"
    fi
}

main "$@"
