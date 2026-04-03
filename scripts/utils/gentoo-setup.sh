#!/usr/bin/env bash
set -euo pipefail

# Gentoo Platform Setup Script
# Configures binpkg, USE flags, and Portage settings

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

DRY_RUN=false

check_gentoo() {
    if [[ ! -f /etc/gentoo-release ]]; then
        log_error "This script must be run on Gentoo Linux"
        exit 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

setup_binpkg() {
    log_info "Configuring binary package support..."
    
    local make_conf="/etc/portage/make.conf"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure binpkg in $make_conf"
        return
    fi
    
    # Backup existing make.conf
    if [[ -f "$make_conf" ]]; then
        cp "$make_conf" "${make_conf}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Add binpkg features if not present
    if ! grep -q "^FEATURES.*binpkg" "$make_conf" 2>/dev/null; then
        log_info "Enabling binary package features..."
        {
            echo ""
            echo "# Binary package support (added by machine-setup)"
            # shellcheck disable=SC2016
            echo 'FEATURES="${FEATURES} binpkg getbinpkg"'
        } >> "$make_conf"
    fi
    
    # Configure binhost if not present
    if ! grep -q "^PORTAGE_BINHOST" "$make_conf" 2>/dev/null; then
        log_info "Configuring binary package host..."
        echo 'PORTAGE_BINHOST="https://distfiles.gentoo.org/releases/amd64/binpackages/17.1/x86-64/"' >> "$make_conf"
    fi
    
    log_success "Binary package support configured"
}

setup_use_flags() {
    log_info "Configuring USE flags..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure USE flags"
        return
    fi
    
    local make_conf="/etc/portage/make.conf"
    
    # Common USE flags for desktop/development systems
    local use_flags=(
        "X"              # X11 support
        "alsa"           # ALSA sound support
        "pulseaudio"     # PulseAudio sound server
        "dbus"           # D-Bus IPC system
        "udev"           # Device manager
        "unicode"        # Unicode support
        "ipv6"           # IPv6 support
        "threads"        # Threading support
        "openssl"        # OpenSSL support
        "zlib"           # Zlib compression
        "bzip2"          # Bzip2 compression
        "lzma"           # LZMA compression
        "png"            # PNG image support
        "jpeg"           # JPEG image support
    )
    
    # Common disabled flags
    local use_flags_disabled=(
        "-systemd"       # No systemd (use OpenRC)
        "-telemetry"     # Disable telemetry
    )
    
    # Check if USE line exists
    if ! grep -q "^USE=" "$make_conf" 2>/dev/null; then
        log_info "Adding USE flags configuration..."
        {
            echo ""
            echo "# USE flags (added by machine-setup)"
            echo "USE=\"${use_flags[*]} ${use_flags_disabled[*]}\""
        } >> "$make_conf"
    else
        log_warn "USE flags already configured, skipping"
    fi
    
    log_success "USE flags configured"
}

configure_portage_dirs() {
    log_info "Configuring Portage directories..."
    
    local dirs=(
        "/etc/portage/package.use"
        "/etc/portage/package.accept_keywords"
        "/etc/portage/package.license"
        "/etc/portage/package.mask"
        "/etc/portage/package.unmask"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY-RUN] Would create $dir"
        else
            if [[ ! -d "$dir" ]]; then
                mkdir -p "$dir"
                log_info "Created $dir"
            else
                log_info "Directory exists: $dir"
            fi
        fi
    done
    
    log_success "Portage directories configured"
}

setup_package_use() {
    log_info "Configuring package-specific USE flags..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure package-specific USE flags"
        return
    fi
    
    local package_use_dir="/etc/portage/package.use"
    local custom_use_file="$package_use_dir/machine-setup"
    
    cat > "$custom_use_file" <<EOF
# Package-specific USE flags configured by machine-setup

# Neovim with Lua and Python support
app-editors/neovim lua python tree-sitter

# Nushell with extra features
app-shells/nushell-bin -systemd

# Ripgrep with PCRE support
sys-apps/ripgrep pcre

# Git with various features
dev-vcs/git curl webdav

# Python with optimizations
dev-lang/python sqlite ncurses

# Rust with system libraries
dev-lang/rust system-llvm
EOF
    
    log_success "Package-specific USE flags configured"
}

setup_accept_keywords() {
    log_info "Configuring package keywords..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure package keywords"
        return
    fi
    
    local keywords_dir="/etc/portage/package.accept_keywords"
    local keywords_file="$keywords_dir/machine-setup"
    
    # Accept ~amd64 keywords for specific packages
    cat > "$keywords_file" <<EOF
# Package keywords configured by machine-setup

# Modern CLI tools (often need ~amd64)
app-shells/nushell-bin ~amd64
app-editors/neovim ~amd64
sys-apps/ripgrep ~amd64
sys-apps/fd ~amd64
app-shells/fzf ~amd64
EOF
    
    log_success "Package keywords configured"
}

configure_make_conf() {
    log_info "Optimizing make.conf..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would optimize make.conf"
        return
    fi
    
    local make_conf="/etc/portage/make.conf"
    
    # Add common optimizations if not present
    local settings=(
        'ACCEPT_LICENSE="* -@EULA"'
        'VIDEO_CARDS="intel i915 nvidia amdgpu"'
        'INPUT_DEVICES="libinput"'
        'LINGUAS="en"'
        'L10N="en-US"'
    )
    
    for setting in "${settings[@]}"; do
        local key
        key=$(echo "$setting" | cut -d'=' -f1)
        if ! grep -q "^$key=" "$make_conf" 2>/dev/null; then
            echo "$setting" >> "$make_conf"
            log_info "Added $key to make.conf"
        fi
    done
    
    log_success "make.conf optimized"
}

sync_repository() {
    log_info "Syncing Portage repository..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would sync Portage repository"
        return
    fi
    
    emerge --sync
    
    log_success "Repository synced"
}

update_world() {
    log_info "Updating @world set..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would update @world"
        return
    fi
    
    log_warn "This may take a while on first run..."
    emerge --update --deep --newuse @world
    
    log_success "@world updated"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Gentoo Linux platform setup script for machine-setup.

Options:
    -n, --dry-run          Show what would be done without executing
    -s, --sync             Sync repository after configuration
    -u, --update           Update @world after configuration
    -h, --help             Show this help message

What this script does:
    1. Configures binary package support (binpkg)
    2. Sets up common USE flags
    3. Creates Portage directories
    4. Configures package-specific USE flags
    5. Sets up package keywords
    6. Optimizes make.conf

Examples:
    $0                     # Configure Gentoo
    $0 --dry-run           # Preview configuration
    $0 --sync --update     # Configure, sync, and update

Note: This script must be run as root on Gentoo Linux.
EOF
}

parse_args() {
    local sync=false
    local update=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -s|--sync)
                sync=true
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
    
    export SYNC_REPO=$sync
    export UPDATE_WORLD=$update
}

main() {
    parse_args "$@"
    
    log_info "========================================="
    log_info "Gentoo Platform Setup"
    log_info "========================================="
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "DRY-RUN MODE - No changes will be made"
    else
        check_gentoo
    fi
    
    setup_binpkg
    setup_use_flags
    configure_portage_dirs
    setup_package_use
    setup_accept_keywords
    configure_make_conf
    
    if [[ "${SYNC_REPO:-false}" == true ]]; then
        sync_repository
    fi
    
    if [[ "${UPDATE_WORLD:-false}" == true ]]; then
        update_world
    fi
    
    log_info "========================================="
    log_success "Gentoo setup complete!"
    log_info "========================================="
    
    if [[ "$DRY_RUN" != true ]]; then
        echo ""
        log_info "Next steps:"
        echo "  1. Review /etc/portage/make.conf"
        echo "  2. Run: emerge --sync"
        echo "  3. Install packages: ./setup.sh --profile full"
        echo ""
    fi
}

main "$@"
