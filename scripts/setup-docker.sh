#!/usr/bin/env bash
set -euo pipefail

log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

setup_docker() {
    log_info "Setting up Docker..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    local user
    user=$(whoami)
    
    if groups "$user" | grep -q docker; then
        log_info "User $user is already in the docker group"
        return
    fi
    
    log_info "Adding user $user to docker group..."
    sudo usermod -aG docker "$user"
    
    log_success "User added to docker group"
    log_warn "You need to log out and log back in for this to take effect"
}

main() {
    setup_docker
}

main "$@"
