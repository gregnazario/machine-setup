#!/usr/bin/env bash
set -euo pipefail

# FreeBSD Platform Setup Script
# Configures pkg, ports, and ZFS settings

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

DRY_RUN=false

check_freebsd() {
    if [[ "$(uname)" != "FreeBSD" ]]; then
        log_error "This script must be run on FreeBSD"
        exit 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

setup_pkg() {
    log_info "Configuring pkg package manager..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure pkg"
        return
    fi
    
    # Initialize pkg if not already done
    if [[ ! -f /usr/local/sbin/pkg ]]; then
        log_info "Initializing pkg..."
        env ASSUME_ALWAYS_YES=YES pkg bootstrap
    else
        log_info "pkg already initialized"
    fi
    
    # Create pkg configuration directory
    mkdir -p /usr/local/etc/pkg/repos
    
    # Configure FreeBSD repository
    cat > /usr/local/etc/pkg/repos/FreeBSD.conf <<EOF
FreeBSD: {
  url: "pkg+http://pkg.FreeBSD.org/\${ABI}/quarterly",
  mirror_type: "srv",
  signature_type: "fingerprints",
  fingerprints: "/usr/share/keys/pkg",
  enabled: yes
}

# Use latest repository for more up-to-date packages
FreeBSD_latest: {
  url: "pkg+http://pkg.FreeBSD.org/\${ABI}/latest",
  mirror_type: "srv",
  signature_type: "fingerprints",
  fingerprints: "/usr/share/keys/pkg",
  enabled: no
}
EOF
    
    # Update package database
    pkg update
    
    log_success "pkg configured"
}

setup_ports() {
    log_info "Configuring ports collection..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure ports"
        return
    fi
    
    local ports_dir="/usr/ports"
    
    if [[ -d "$ports_dir" ]]; then
        log_info "Ports collection already exists"
        log_info "To update: portsnap fetch update"
    else
        log_info "Fetching ports collection..."
        portsnap fetch extract
    fi
    
    log_success "Ports collection configured"
}

configure_make_conf() {
    log_info "Configuring /etc/make.conf..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure make.conf"
        return
    fi
    
    local make_conf="/etc/make.conf"
    
    # Backup existing make.conf
    if [[ -f "$make_conf" ]]; then
        cp "$make_conf" "${make_conf}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Add common settings
    cat >> "$make_conf" <<EOF

# Added by machine-setup
# Use binary packages when available
WITH_PKGNG=yes

# Optimizations
CPUTYPE?=native
MAKE_JOBS_NUMBER?=4

# License acceptance
LICENSES_ACCEPTED+=GPLv2 GPLv3 LGPL21 LGPL3
EOF
    
    log_success "make.conf configured"
}

setup_zfs() {
    log_info "Checking ZFS support..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would check ZFS support"
        return
    fi
    
    # Check if ZFS is available
    if kldstat -q -m zfs; then
        log_info "ZFS kernel module loaded"
        
        # Enable ZFS at boot
        if ! grep -q "zfs_enable=YES" /etc/rc.conf; then
            echo 'zfs_enable="YES"' >> /etc/rc.conf
            log_info "ZFS enabled at boot"
        fi
    else
        log_info "ZFS not detected (this is normal for UFS systems)"
    fi
    
    log_success "ZFS check complete"
}

configure_rc_conf() {
    log_info "Configuring /etc/rc.conf..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure rc.conf"
        return
    fi
    
    local rc_conf="/etc/rc.conf"
    
    # Common services to enable
    local services=(
        "sshd_enable=YES"
        "docker_enable=YES"
        "syncthing_enable=YES"
    )
    
    for service in "${services[@]}"; do
        local key
        key=$(echo "$service" | cut -d'=' -f1)
        if ! grep -q "^$key=" "$rc_conf" 2>/dev/null; then
            echo "$service" >> "$rc_conf"
            log_info "Added: $service"
        else
            log_info "Already configured: $key"
        fi
    done
    
    log_success "rc.conf configured"
}

configure_sysctl() {
    log_info "Configuring /etc/sysctl.conf..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure sysctl.conf"
        return
    fi
    
    local sysctl_conf="/etc/sysctl.conf"
    
    # Backup existing sysctl.conf
    if [[ -f "$sysctl_conf" ]]; then
        cp "$sysctl_conf" "${sysctl_conf}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Common sysctl settings
    local settings=(
        "kern.ipc.shmmax=67108864"
        "kern.ipc.shmall=32768"
        "security.bsd.see_other_uids=0"
        "security.bsd.see_other_gids=0"
    )
    
    for setting in "${settings[@]}"; do
        if ! grep -q "^$setting" "$sysctl_conf" 2>/dev/null; then
            echo "$setting" >> "$sysctl_conf"
        fi
    done
    
    log_success "sysctl.conf configured"
}

install_freebsd_tools() {
    log_info "Installing FreeBSD-specific tools..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would install FreeBSD tools"
        return
    fi
    
    local tools=(
        "sudo"
        "bash"
        "bash-completion"
        "wget"
        "curl"
        "git"
        "portmaster"
    )
    
    for tool in "${tools[@]}"; do
        if ! pkg info "$tool" >/dev/null 2>&1; then
            log_info "Installing: $tool"
            pkg install -y "$tool"
        else
            log_info "Already installed: $tool"
        fi
    done
    
    log_success "FreeBSD tools installed"
}

configure_shell() {
    log_info "Configuring default shell..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure shell"
        return
    fi
    
    # Check if bash is installed
    if [[ -f /usr/local/bin/bash ]]; then
        # Add to shells database
        if ! grep -q "/usr/local/bin/bash" /etc/shells; then
            echo "/usr/local/bin/bash" >> /etc/shells
        fi
        
        log_info "bash installed and added to /etc/shells"
        log_info "To change default shell: chsh -s /usr/local/bin/bash \$USER"
    fi
    
    log_success "Shell configured"
}

configure_timezone() {
    log_info "Configuring timezone..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure timezone"
        return
    fi
    
    if [[ ! -f /etc/localtime ]]; then
        # Common timezones
        tzsetup -C
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
    
    # Update FreeBSD base system
    freebsd-update fetch install
    
    # Update packages
    pkg upgrade -y
    
    log_success "System updated"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

FreeBSD platform setup script for machine-setup.

Options:
    -n, --dry-run          Show what would be done without executing
    -u, --update           Update system after configuration
    -h, --help             Show this help message

What this script does:
    1. Configures pkg package manager
    2. Sets up ports collection (optional)
    3. Configures make.conf for ports building
    4. Checks and configures ZFS support
    5. Enables common services in rc.conf
    6. Configures system settings (sysctl)
    7. Installs FreeBSD-specific tools
    8. Configures bash shell
    9. Optionally updates the system

Examples:
    $0                     # Configure FreeBSD
    $0 --dry-run           # Preview configuration
    $0 --update            # Configure and update

Note: This script must be run as root on FreeBSD.
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
    log_info "FreeBSD Platform Setup"
    log_info "========================================="
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "DRY-RUN MODE - No changes will be made"
    else
        check_freebsd
    fi
    
    setup_pkg
    install_freebsd_tools
    setup_ports
    configure_make_conf
    configure_shell
    setup_zfs
    configure_rc_conf
    configure_sysctl
    configure_timezone
    
    if [[ "${UPDATE_SYSTEM:-false}" == true ]]; then
        update_system
    fi
    
    log_info "========================================="
    log_success "FreeBSD setup complete!"
    log_info "========================================="
    
    if [[ "$DRY_RUN" != true ]]; then
        echo ""
        log_info "Next steps:"
        echo "  1. Reboot if kernel was updated"
        echo "  2. Install packages: ./setup.sh --profile full"
        echo "  3. To use bash: chsh -s /usr/local/bin/bash \$USER"
        echo "  4. Update ports: portsnap fetch update"
        echo ""
    fi
}

main "$@"
