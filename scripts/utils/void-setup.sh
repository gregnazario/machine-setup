#!/usr/bin/env bash
set -euo pipefail

# Void Linux Platform Setup Script
# Configures XBPS repositories and runit services

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

DRY_RUN=false

check_void() {
    if [[ ! -f /etc/os-release ]] || ! grep -q "void" /etc/os-release; then
        log_error "This script must be run on Void Linux"
        exit 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

setup_repos() {
    log_info "Configuring XBPS repositories..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure repositories"
        return
    fi
    
    # Enable nonfree repository
    if ! xbps-query void-repo-nonfree &>/dev/null; then
        log_info "Enabling nonfree repository..."
        xbps-install -y void-repo-nonfree
    else
        log_info "Nonfree repository already enabled"
    fi
    
    # Enable multilib repository (for 32-bit compatibility)
    if ! xbps-query void-repo-multilib &>/dev/null; then
        log_info "Enabling multilib repository..."
        xbps-install -y void-repo-multilib
    else
        log_info "Multilib repository already enabled"
    fi
    
    # Sync repository data
    log_info "Syncing repository data..."
    xbps-install -S
    
    log_success "Repositories configured"
}

configure_xbps() {
    log_info "Configuring XBPS settings..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure XBPS"
        return
    fi
    
    local xbps_conf="/etc/xbps.d/machine-setup.conf"
    
    # Create xbps.d directory if it doesn't exist
    mkdir -p /etc/xbps.d
    
    # Configure XBPS settings
    cat > "$xbps_conf" <<EOF
# XBPS configuration (added by machine-setup)

# Enable file verification
XBPS_PKG_CHECKSUM=1

# Keep downloaded packages
XBPS_KEEP_PKGS=1

# Use xbps-dgraph for dependencies
XBPS_BUILD_REASON=1
EOF
    
    log_success "XBPS configured"
}

setup_runit_services() {
    log_info "Configuring runit services..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure runit services"
        return
    fi
    
    local services=(
        "sshd"
        "docker"
        "syncthing"
        "cronie"
        "acpid"
    )
    
    for service in "${services[@]}"; do
        if [[ -d "/etc/sv/$service" ]]; then
            if [[ ! -L "/var/service/$service" ]]; then
                log_info "Enabling service: $service"
                ln -s "/etc/sv/$service" "/var/service/"
            else
                log_info "Service already enabled: $service"
            fi
        else
            log_warn "Service not found: $service"
        fi
    done
    
    log_success "Services configured"
}

configure_locale() {
    log_info "Configuring locale..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure locale"
        return
    fi
    
    # Set default locale
    if [[ -f /etc/locale.conf ]]; then
        if ! grep -q "LANG=en_US.UTF-8" /etc/locale.conf; then
            echo "LANG=en_US.UTF-8" >> /etc/locale.conf
            echo "LC_COLLATE=C" >> /etc/locale.conf
        fi
    else
        cat > /etc/locale.conf <<EOF
LANG=en_US.UTF-8
LC_COLLATE=C
EOF
    fi
    
    log_success "Locale configured"
}

configure_hostname() {
    log_info "Configuring hostname..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure hostname"
        return
    fi
    
    if [[ ! -f /etc/hostname ]]; then
        read -rp "Enter hostname [void]: " hostname
        hostname=${hostname:-void}
        echo "$hostname" > /etc/hostname
        log_info "Hostname set to: $hostname"
    else
        log_info "Hostname already configured"
    fi
    
    log_success "Hostname configured"
}

setup_void_specific() {
    log_info "Installing Void-specific tools..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would install Void-specific tools"
        return
    fi
    
    local tools=(
        "void-repo-nonfree"
        "void-repo-multilib"
        "base-devel"
        "bash-completion"
    )
    
    for tool in "${tools[@]}"; do
        if ! xbps-query "$tool" &>/dev/null; then
            log_info "Installing: $tool"
            xbps-install -y "$tool"
        else
            log_info "Already installed: $tool"
        fi
    done
    
    log_success "Void-specific tools installed"
}

configure_timezone() {
    log_info "Configuring timezone..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure timezone"
        return
    fi
    
    if [[ ! -L /etc/localtime ]]; then
        # Try to detect timezone
        if [[ -f /usr/share/zoneinfo/America/New_York ]]; then
            ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
            log_info "Timezone set to America/New_York"
        else
            log_warn "Please configure timezone manually: ln -sf /usr/share/zoneinfo/YOUR_TIMEZONE /etc/localtime"
        fi
    else
        log_info "Timezone already configured"
    fi
    
    log_success "Timezone configured"
}

update_system() {
    log_info "Updating system..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would update system"
        return
    fi
    
    xbps-install -Su xbps
    xbps-install -u
    
    log_success "System updated"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Void Linux platform setup script for machine-setup.

Options:
    -n, --dry-run          Show what would be done without executing
    -u, --update           Update system after configuration
    -h, --help             Show this help message

What this script does:
    1. Configures XBPS repositories (nonfree, multilib)
    2. Configures XBPS settings
    3. Enables runit services (sshd, docker, syncthing, cronie)
    4. Configures locale and timezone
    5. Installs Void-specific tools
    6. Optionally updates the system

Examples:
    $0                     # Configure Void Linux
    $0 --dry-run           # Preview configuration
    $0 --update            # Configure and update

Note: This script must be run as root on Void Linux.
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
    log_info "Void Linux Platform Setup"
    log_info "========================================="
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "DRY-RUN MODE - No changes will be made"
    else
        check_void
    fi
    
    setup_repos
    configure_xbps
    setup_void_specific
    configure_locale
    configure_timezone
    configure_hostname
    setup_runit_services
    
    if [[ "${UPDATE_SYSTEM:-false}" == true ]]; then
        update_system
    fi
    
    log_info "========================================="
    log_success "Void Linux setup complete!"
    log_info "========================================="
    
    if [[ "$DRY_RUN" != true ]]; then
        echo ""
        log_info "Next steps:"
        echo "  1. Reboot if kernel was updated"
        echo "  2. Install packages: ./setup.sh --profile full"
        echo "  3. Check services: sv status /var/service/*"
        echo ""
    fi
}

main "$@"
