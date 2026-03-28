#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/profile-loader.sh"
source "${SCRIPT_DIR}/ini-parser.sh"

# Only initialize these if not already set (e.g., when sourced)
PROFILE="${PROFILE:-}"
DRY_RUN="${DRY_RUN:-false}"

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
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

install_packages_apt() {
    log_info "Installing packages with apt..."
    
    local packages="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would install: $packages"
        return
    fi
    
    sudo apt update
    sudo apt install -y $packages
}

install_packages_dnf() {
    log_info "Installing packages with dnf..."
    
    local packages="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would install: $packages"
        return
    fi
    
    sudo dnf install -y $packages
}

install_packages_emerge() {
    log_info "Installing packages with emerge..."
    
    local packages="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would install: $packages"
        return
    fi
    
    sudo emerge --noreplace $packages
}

install_packages_xbps() {
    log_info "Installing packages with xbps..."
    
    local packages="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would install: $packages"
        return
    fi
    
    sudo xbps-install -S $packages
}

install_packages_homebrew() {
    log_info "Installing packages with homebrew..."
    
    local packages="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would install: $packages"
        return
    fi
    
    brew install $packages
}

install_packages_pkg() {
    log_info "Installing packages with pkg (FreeBSD)..."
    
    local packages="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would install: $packages"
        return
    fi
    
    sudo pkg install -y $packages
}

install_packages_winget() {
    log_info "Installing packages with winget..."
    
    local packages="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would install: $packages"
        return
    fi
    
    for package in $packages; do
        winget install --id "$package" --silent
    done
}

install_packages_pacman() {
    log_info "Installing packages with pacman..."
    
    local packages="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would install: $packages"
        return
    fi
    
    sudo pacman -S --noconfirm --needed $packages
}

install_packages_apk() {
    log_info "Installing packages with apk (Alpine)..."
    
    local packages="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would install: $packages"
        return
    fi
    
    sudo apk add $packages
}

install_packages_zypper() {
    log_info "Installing packages with zypper (OpenSUSE)..."
    
    local packages="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would install: $packages"
        return
    fi
    
    sudo zypper install -y $packages
}

get_mapped_package_name() {
    local package_name="$1"
    local common_file="${SCRIPT_DIR}/../packages/common.conf"
    local mapped_name
    local common_content
    local platform_mapped
    
    if [[ ! -f "$common_file" ]]; then
        echo "$package_name"
        return
    fi
    
    common_content=$(cat "$common_file")
    platform_mapped=$(ini_get "$common_file" "package_mapping.${package_name}" "$PLATFORM" "")

    if [[ -n "$platform_mapped" ]]; then
        echo "$platform_mapped"
    else
        echo "$package_name"
    fi
}

collect_packages() {
    local packages=""
    local profile_packages
    local mapped_package
    
    profile_packages=$(get_profile_packages)
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            for package in $line; do
                mapped_package=$(get_mapped_package_name "$package")
                packages="$packages $mapped_package"
            done
        fi
    done <<< "$profile_packages"
    
    local platform_file="${SCRIPT_DIR}/../packages/platforms/${PLATFORM}.conf"
    if [[ -f "$platform_file" ]]; then
        local platform_packages
        
        platform_packages=$(ini_get "$platform_file" "packages.base" "packages" "")
        
        if [[ -n "$platform_packages" ]]; then
            for package in $platform_packages; do
                packages="$packages $package"
            done
        fi
    fi
    
    echo "$packages" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

install_packages() {
    local packages="$1"
    
    case "$PACKAGE_MANAGER" in
        apt)
            install_packages_apt "$packages"
            ;;
        dnf)
            install_packages_dnf "$packages"
            ;;
        emerge)
            install_packages_emerge "$packages"
            ;;
        xbps)
            install_packages_xbps "$packages"
            ;;
        homebrew)
            install_packages_homebrew "$packages"
            ;;
        pkg)
            install_packages_pkg "$packages"
            ;;
        winget)
            install_packages_winget "$packages"
            ;;
        pacman)
            install_packages_pacman "$packages"
            ;;
        apk)
            install_packages_apk "$packages"
            ;;
        zypper)
            install_packages_zypper "$packages"
            ;;
        *)
            log_error "Unsupported package manager: $PACKAGE_MANAGER"
            exit 1
            ;;
    esac
}

main() {
    parse_args "$@"
    
    detect_platform
    log_info "Detected platform: $PLATFORM"
    log_info "Package manager: $PACKAGE_MANAGER"
    
    if [[ -z "$PROFILE" ]]; then
        PROFILE=$(get_default_profile_for_platform)
        log_info "Using default profile: $PROFILE"
    fi
    
    load_profile "$PROFILE"
    log_info "Using profile: $PROFILE"
    
    local packages
    packages=$(collect_packages)
    log_info "Packages to install: $packages"
    
    if [[ -n "$packages" ]]; then
        install_packages "$packages"
        log_success "Package installation complete!"
    else
        log_warn "No packages to install"
    fi
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
