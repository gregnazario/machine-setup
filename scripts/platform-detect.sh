#!/usr/bin/env bash
set -euo pipefail

PLATFORM=""
PACKAGE_MANAGER=""

log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

detect_platform() {
    if [[ "$(uname)" == "Darwin" ]]; then
        PLATFORM="macos"
        PACKAGE_MANAGER="homebrew"
    elif [[ "$(uname)" == "FreeBSD" ]]; then
        PLATFORM="freebsd"
        PACKAGE_MANAGER="pkg"
    elif [[ "$(uname -r)" == *"Microsoft"* ]] || [[ "$(uname -r)" == *"microsoft"* ]]; then
        PLATFORM="windows"
        PACKAGE_MANAGER="winget"
    elif [[ -f /etc/os-release ]]; then
        source /etc/os-release
        
        case "$ID" in
            fedora)
                PLATFORM="fedora"
                PACKAGE_MANAGER="dnf"
                ;;
            ubuntu|linuxmint|pop|debian)
                PLATFORM="ubuntu"
                PACKAGE_MANAGER="apt"
                ;;
            raspbian)
                PLATFORM="raspberrypios"
                PACKAGE_MANAGER="apt"
                ;;
            gentoo)
                PLATFORM="gentoo"
                PACKAGE_MANAGER="emerge"
                ;;
            void)
                PLATFORM="void"
                PACKAGE_MANAGER="xbps"
                ;;
            *)
                log_error "Unsupported Linux distribution: $ID"
                log_error "Supported: fedora, ubuntu, debian, gentoo, void, raspbian"
                exit 1
                ;;
        esac
    else
        log_error "Unable to detect platform"
        exit 1
    fi
    
    export PLATFORM
    export PACKAGE_MANAGER
}

get_package_manager() {
    echo "$PACKAGE_MANAGER"
}

get_platform() {
    echo "$PLATFORM"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_platform
    echo "Platform: $PLATFORM"
    echo "Package Manager: $PACKAGE_MANAGER"
fi
