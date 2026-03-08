#!/usr/bin/env bash
set -euo pipefail

# Arch Linux Platform Setup Script
# Configures pacman, AUR helper, and system settings

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

check_arch() {
    if [[ ! -f /etc/os-release ]] || ! grep -qi "arch\|manjaro\|endeavouros\|garuda" /etc/os-release; then
        log_error "This script must be run on Arch Linux or its derivatives"
        exit 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

configure_pacman() {
    log_info "Configuring pacman..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure pacman"
        return
    fi
    
    local pacman_conf="/etc/pacman.conf"
    
    # Backup pacman.conf
    cp "$pacman_conf" "${pacman_conf}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Enable parallel downloads
    if ! grep -q "^ParallelDownloads" "$pacman_conf"; then
        sed -i '/^#ParallelDownloads/s/^#//' "$pacman_conf"
        log_info "Enabled parallel downloads"
    fi
    
    # Enable color output
    if ! grep -q "^Color" "$pacman_conf"; then
        sed -i '/^#Color/s/^#//' "$pacman_conf"
        log_info "Enabled color output"
    fi
    
    # Enable verbose package lists
    if ! grep -q "^VerbosePkgLists" "$pacman_conf"; then
        sed -i '/^#VerbosePkgLists/s/^#//' "$pacman_conf"
        log_info "Enabled verbose package lists"
    fi
    
    # Enable ILoveCandy (fun progress bar)
    if ! grep -q "^ILoveCandy" "$pacman_conf"; then
        echo "ILoveCandy" >> "$pacman_conf"
        log_info "Enabled ILoveCandy"
    fi
    
    log_success "pacman configured"
}

setup_aur_helper() {
    log_info "Setting up AUR helper (yay)..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would install yay"
        return
    fi
    
    # Check if yay is already installed
    if command -v yay &>/dev/null; then
        log_info "yay is already installed"
        return
    fi
    
    # Install dependencies
    pacman -S --needed --noconfirm git base-devel
    
    # Create temporary user for building
    local build_user="aur-builder"
    if ! id "$build_user" &>/dev/null; then
        useradd -m -G wheel "$build_user"
        echo "$build_user ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$build_user"
    fi
    
    # Install yay
    local tmp_dir=$(mktemp -d)
    cd "$tmp_dir"
    
    su - "$build_user" -c "git clone https://aur.archlinux.org/yay.git $tmp_dir/yay"
    cd "$tmp_dir/yay"
    su - "$build_user" -c "makepkg -si --noconfirm"
    
    # Cleanup
    cd /
    rm -rf "$tmp_dir"
    
    # Remove build user
    userdel -r "$build_user" 2>/dev/null || true
    rm -f "/etc/sudoers.d/$build_user"
    
    log_success "yay installed"
}

configure_makepkg() {
    log_info "Configuring makepkg..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure makepkg"
        return
    fi
    
    local makepkg_conf="/etc/makepkg.conf"
    
    # Backup makepkg.conf
    cp "$makepkg_conf" "${makepkg_conf}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Enable parallel compilation
    local nproc=$(nproc)
    sed -i "s/^#MAKEFLAGS=.*/MAKEFLAGS=\"-j${nproc}\"/" "$makepkg_conf"
    
    # Use all cores for compression
    sed -i 's/^COMPRESSXZ=.*/COMPRESSXZ=(xz -c -z - --threads=0)/' "$makepkg_conf"
    sed -i 's/^COMPRESSZST=.*/COMPRESSZST=(zstd -c -z -q - --threads=0)/' "$makepkg_conf"
    
    log_success "makepkg configured"
}

configure_pacman_hooks() {
    log_info "Configuring pacman hooks..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure pacman hooks"
        return
    fi
    
    local hooks_dir="/etc/pacman.d/hooks"
    mkdir -p "$hooks_dir"
    
    # Create hook to clean cache
    cat > "$hooks_dir/clean-cache.hook" <<'EOF'
[Trigger]
Operation = Remove
Operation = Install
Operation = Upgrade
Type = Package
Target = *

[Action]
Description = Cleaning pacman cache...
When = PostTransaction
Exec = /usr/bin/paccache -rk2
EOF
    
    log_success "pacman hooks configured"
}

setup_reflector() {
    log_info "Setting up reflector for mirror management..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would setup reflector"
        return
    fi
    
    pacman -S --needed --noconfirm reflector
    
    # Create reflector configuration
    cat > /etc/xdg/reflector/reflector.conf <<'EOF'
# Reflector configuration
--save /etc/pacman.d/mirrorlist
--protocol https
--country US,CA,GB
--latest 20
--sort rate
EOF
    
    # Enable reflector timer
    systemctl enable reflector.timer
    systemctl start reflector.timer
    
    log_success "Reflector configured"
}

setup_arch_specific() {
    log_info "Installing Arch-specific tools..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would install Arch tools"
        return
    fi
    
    local tools=(
        "pacman-contrib"
        "pkgfile"
        "archlinux-keyring"
    )
    
    for tool in "${tools[@]}"; do
        if ! pacman -Qi "$tool" &>/dev/null; then
            log_info "Installing: $tool"
            pacman -S --noconfirm --needed "$tool"
        else
            log_info "Already installed: $tool"
        fi
    done
    
    # Update pkgfile database
    systemctl enable pkgfile-update.timer
    systemctl start pkgfile-update.timer
    pkgfile --update
    
    log_success "Arch tools installed"
}

update_system() {
    log_info "Updating system..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would update system"
        return
    fi
    
    pacman -Syu --noconfirm
    
    log_success "System updated"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Arch Linux platform setup script for machine-setup.

Options:
    -n, --dry-run          Show what would be done without executing
    -u, --update           Update system after configuration
    -h, --help             Show this help message

What this script does:
    1. Configures pacman (parallel downloads, color, etc.)
    2. Installs and configures yay (AUR helper)
    3. Optimizes makepkg for parallel compilation
    4. Sets up pacman hooks for maintenance
    5. Configures reflector for mirror management
    6. Installs Arch-specific tools
    7. Optionally updates the system

Examples:
    $0                     # Configure Arch Linux
    $0 --dry-run           # Preview configuration
    $0 --update            # Configure and update

Note: This script must be run as root on Arch Linux or derivatives.
EOF
}

parse_args() {
    local update=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -u|--update)
                update=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    export UPDATE_SYSTEM=$update
}

main() {
    parse_args "$@"
    
    log_info "========================================="
    log_info "Arch Linux Platform Setup"
    log_info "========================================="
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "DRY-RUN MODE - No changes will be made"
    else
        check_arch
    fi
    
    configure_pacman
    setup_arch_specific
    configure_makepkg
    configure_pacman_hooks
    setup_reflector
    setup_aur_helper
    
    if [[ "${UPDATE_SYSTEM:-false}" == true ]]; then
        update_system
    fi
    
    log_info "========================================="
    log_success "Arch Linux setup complete!"
    log_info "========================================="
    
    if [[ "$DRY_RUN" != true ]]; then
        echo ""
        log_info "Next steps:"
        echo "  1. Reboot if kernel was updated"
        echo "  2. Install packages: ./setup.sh --profile full"
        echo "  3. Use yay for AUR packages: yay -S package-name"
        echo ""
    fi
}

main "$@"
