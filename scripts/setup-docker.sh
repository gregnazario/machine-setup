#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/platform-detect.sh"

setup_docker() {
    log_info "Setting up Docker..."

    # Set up Docker APT repository with GPG verification on apt-based platforms
    detect_platform
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        source "${SCRIPT_DIR}/setup-docker-repo.sh"
        setup_docker_repo "$PLATFORM"
    fi

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
