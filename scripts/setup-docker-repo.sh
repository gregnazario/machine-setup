#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Docker's official GPG key fingerprint
# Full fingerprint: 9DC858229FC7DD38854AE2D88D81803C0EBFCD88
DOCKER_GPG_FINGERPRINT="9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
DOCKER_GPG_URL="https://download.docker.com/linux/ubuntu/gpg"
DOCKER_KEYRING="/usr/share/keyrings/docker-archive-keyring.gpg"

setup_docker_repo() {
    local platform="$1"

    if [[ "$platform" != "ubuntu" && "$platform" != "debian" && "$platform" != "wsl" ]]; then
        return 0
    fi

    # For WSL, derive the underlying distro for Docker's repo URL
    # Docker publishes repos for ubuntu/debian, not "wsl"
    local docker_distro="$platform"
    if [[ "$platform" == "wsl" ]]; then
        if [[ -f /etc/os-release ]]; then
            docker_distro=$(. /etc/os-release && echo "${ID:-ubuntu}")
        else
            docker_distro="ubuntu"
        fi
        log_info "WSL detected, using Docker repo for: $docker_distro"
    fi

    if [[ -f "$DOCKER_KEYRING" ]]; then
        log_info "Docker GPG keyring already exists, verifying..."
        if gpg --no-default-keyring --keyring "$DOCKER_KEYRING" --list-keys 2>/dev/null | grep -qi "${DOCKER_GPG_FINGERPRINT:(-16)}"; then
            log_success "Docker GPG key fingerprint verified"
            return 0
        else
            log_warn "Docker GPG key fingerprint mismatch, re-downloading..."
            sudo rm -f "$DOCKER_KEYRING"
        fi
    fi

    log_info "Adding Docker GPG key with fingerprint verification..."

    local tmp_key
    tmp_key=$(mktemp)
    curl -fsSL "$DOCKER_GPG_URL" -o "$tmp_key"

    local tmp_keyring
    tmp_keyring=$(mktemp)
    gpg --no-default-keyring --keyring "$tmp_keyring" --import "$tmp_key" 2>/dev/null

    local tmp_export
    tmp_export=$(mktemp)

    if gpg --no-default-keyring --keyring "$tmp_keyring" --list-keys --with-colons 2>/dev/null | grep -q "$DOCKER_GPG_FINGERPRINT"; then
        log_success "GPG key fingerprint matches: $DOCKER_GPG_FINGERPRINT"
        sudo mkdir -p "$(dirname "$DOCKER_KEYRING")"
        gpg --no-default-keyring --keyring "$tmp_keyring" --export --output "$tmp_export" 2>/dev/null
        sudo mv "$tmp_export" "$DOCKER_KEYRING"
        sudo chmod a+r "$DOCKER_KEYRING"
    else
        log_error "Docker GPG key fingerprint verification FAILED"
        log_error "Expected: $DOCKER_GPG_FINGERPRINT"
        log_error "This could indicate a supply-chain attack. Aborting Docker repo setup."
        rm -f "$tmp_key" "$tmp_keyring" "${tmp_keyring}~" "$tmp_export"
        return 1
    fi

    rm -f "$tmp_key" "$tmp_keyring" "${tmp_keyring}~"

    local codename
    codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
    local arch
    arch=$(dpkg --print-architecture)

    echo "deb [arch=$arch signed-by=$DOCKER_KEYRING] https://download.docker.com/linux/${docker_distro} $codename stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -qq

    log_success "Docker repository added and verified"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_docker_repo "${1:-ubuntu}"
fi
