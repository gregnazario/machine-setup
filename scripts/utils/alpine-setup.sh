#!/usr/bin/env bash
set -euo pipefail

# Alpine Linux Platform Setup Script
# Configures apk and OpenRC services

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

check_alpine() {
    if [[ ! -f /etc/os-release ]] || ! grep -q "alpine" /etc/os-release; then
        log_error "This script must be run on Alpine Linux"
        exit 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

setup_repos() {
    log_info "Configuring APK repositories..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure repositories"
        return
    fi
    
    local repos_file="/etc/apk/repositories"
    
    # Backup repositories file
    cp "$repos_file" "${repos_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Detect Alpine version
    local alpine_version
    alpine_version=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2 | cut -d'.' -f1,2)
    
    # Configure repositories
    cat > "$repos_file" <<EOF
# Main repository
https://dl-cdn.alpinelinux.org/alpine/v${alpine_version}/main

# Community repository
https://dl-cdn.alpinelinux.org/alpine/v${alpine_version}/community

# Testing repository (optional - uncomment if needed)
# https://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF
    
    # Update package index
    apk update
    
    log_success "Repositories configured"
}

configure_apk() {
    log_info "Configuring APK settings..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure APK"
        return
    fi
    
    # Create APK cache directory
    mkdir -p /var/cache/apk
    
    # Configure APK to use cache
    if ! grep -q "cache" /etc/apk/arch; then
        echo "cache /var/cache/apk" >> /etc/apk/arch
    fi
    
    log_success "APK configured"
}

setup_openrc_services() {
    log_info "Configuring OpenRC services..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure OpenRC services"
        return
    fi
    
    local services=(
        "sshd"
        "docker"
        "syncthing"
        "cron"
    )
    
    for service in "${services[@]}"; do
        if rc-status | grep -q "$service"; then
            log_info "Service already in runlevel: $service"
        else
            # Add service to default runlevel
            rc-update add "$service" default 2>/dev/null || log_warn "Service not found: $service"
            
            # Start service
            rc-service "$service" start 2>/dev/null || log_warn "Could not start: $service"
        fi
    done
    
    log_success "OpenRC services configured"
}

install_alpine_tools() {
    log_info "Installing Alpine-specific tools..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would install Alpine tools"
        return
    fi
    
    local tools=(
        "bash"
        "bash-completion"
        "sudo"
        "curl"
        "wget"
        "git"
        "build-base"
        "linux-headers"
    )
    
    for tool in "${tools[@]}"; do
        if ! apk info -e "$tool" &>/dev/null; then
            log_info "Installing: $tool"
            apk add "$tool"
        else
            log_info "Already installed: $tool"
        fi
    done
    
    log_success "Alpine tools installed"
}

configure_shell() {
    log_info "Configuring default shell..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure shell"
        return
    fi
    
    # Add bash to /etc/shells
    if [[ -f /bin/bash ]]; then
        if ! grep -q "/bin/bash" /etc/shells; then
            echo "/bin/bash" >> /etc/shells
        fi
        log_info "bash added to /etc/shells"
        log_info "To change default shell: chsh -s /bin/bash"
    fi
    
    log_success "Shell configured"
}

configure_timezone() {
    log_info "Configuring timezone..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure timezone"
        return
    fi
    
    # Install timezone data
    apk add tzdata
    
    # Set timezone (default to UTC)
    if [[ ! -f /etc/timezone ]]; then
        cp /usr/share/zoneinfo/UTC /etc/localtime
        echo "UTC" > /etc/timezone
    fi
    
    log_success "Timezone configured"
}

setup_networking() {
    log_info "Configuring networking..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure networking"
        return
    fi
    
    # Install networking tools
    apk add networkmanager
    
    # Enable NetworkManager
    rc-update add networkmanager default
    rc-service networkmanager start
    
    log_success "Networking configured"
}

configure_hostname() {
    log_info "Configuring hostname..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure hostname"
        return
    fi
    
    if [[ ! -f /etc/hostname ]]; then
        read -rp "Enter hostname [alpine]: " hostname
        hostname=${hostname:-alpine}
        echo "$hostname" > /etc/hostname
        log_info "Hostname set to: $hostname"
    else
        log_info "Hostname already configured"
    fi
    
    log_success "Hostname configured"
}

setup_sudo() {
    log_info "Configuring sudo..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would configure sudo"
        return
    fi
    
    # Enable wheel group in sudoers
    if [[ -f /etc/sudoers ]]; then
        if ! grep -q "^%wheel" /etc/sudoers; then
            echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
            log_info "Wheel group enabled in sudoers"
        fi
    fi
    
    log_success "Sudo configured"
}

update_system() {
    log_info "Updating system..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would update system"
        return
    fi
    
    apk update
    apk upgrade
    
    log_success "System updated"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Alpine Linux platform setup script for machine-setup.

Options:
    -n, --dry-run          Show what would be done without executing
    -u, --update           Update system after configuration
    -h, --help             Show this help message

What this script does:
    1. Configures APK repositories (main, community)
    2. Sets up APK cache
    3. Configures OpenRC services (sshd, docker, syncthing, cron)
    4. Installs Alpine-specific tools
    5. Configures bash shell
    6. Sets up timezone and hostname
    7. Configures networking with NetworkManager
    8. Sets up sudo
    9. Optionally updates the system

Examples:
    $0                     # Configure Alpine Linux
    $0 --dry-run           # Preview configuration
    $0 --update            # Configure and update

Note: This script must be run as root on Alpine Linux.
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
    log_info "Alpine Linux Platform Setup"
    log_info "========================================="
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "DRY-RUN MODE - No changes will be made"
    else
        check_alpine
    fi
    
    setup_repos
    configure_apk
    install_alpine_tools
    configure_shell
    configure_timezone
    configure_hostname
    setup_sudo
    setup_networking
    setup_openrc_services
    
    if [[ "${UPDATE_SYSTEM:-false}" == true ]]; then
        update_system
    fi
    
    log_info "========================================="
    log_success "Alpine Linux setup complete!"
    log_info "========================================="
    
    if [[ "$DRY_RUN" != true ]]; then
        echo ""
        log_info "Next steps:"
        echo "  1. Reboot if kernel was updated"
        echo "  2. Install packages: ./setup.sh --profile full"
        echo "  3. To use bash: chsh -s /bin/bash"
        echo "  4. Check services: rc-status"
        echo ""
    fi
}

main "$@"
