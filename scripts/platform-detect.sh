#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

PLATFORM=""
PACKAGE_MANAGER=""

detect_platform() {
    if [[ "$(uname)" == "Darwin" ]]; then
        PLATFORM="macos"
        PACKAGE_MANAGER="homebrew"
    elif [[ "$(uname)" == "FreeBSD" ]]; then
        PLATFORM="freebsd"
        PACKAGE_MANAGER="pkg"
    elif [[ "$(uname -r)" == *"Microsoft"* ]] || [[ "$(uname -r)" == *"microsoft"* ]]; then
        # WSL2 — a full Linux environment; use the native Linux package manager
        PLATFORM="wsl"
        PACKAGE_MANAGER="apt"
    elif [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]] || [[ "$(uname -s)" == CYGWIN* ]]; then
        # Native Windows (Git Bash / MSYS2 / Cygwin)
        PLATFORM="windows"
        PACKAGE_MANAGER="winget"
    elif [[ -n "${ANDROID_ROOT:-}" ]] || [[ -n "${PREFIX:-}" && "${PREFIX:-}" == */com.termux/* ]]; then
        # Android Termux
        PLATFORM="termux"
        PACKAGE_MANAGER="termux-pkg"
    elif [[ -f /dev/.cros_milestone ]] || [[ -n "${CHROMEOS_RELEASE_NAME:-}" ]]; then
        # ChromeOS Crostini (Debian-based Linux container)
        PLATFORM="chromeos"
        PACKAGE_MANAGER="apt"
    elif [[ -f /etc/os-release ]]; then
        source /etc/os-release
        
        case "$ID" in
            fedora)
                PLATFORM="fedora"
                PACKAGE_MANAGER="dnf"
                ;;
            ubuntu|linuxmint|pop)
                PLATFORM="ubuntu"
                PACKAGE_MANAGER="apt"
                ;;
            debian)
                PLATFORM="debian"
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
            arch|manjaro|endeavouros|garuda)
                PLATFORM="arch"
                PACKAGE_MANAGER="pacman"
                ;;
            alpine)
                PLATFORM="alpine"
                PACKAGE_MANAGER="apk"
                ;;
            nixos)
                PLATFORM="nixos"
                PACKAGE_MANAGER="nix"
                ;;
            opensuse*)
                PLATFORM="opensuse"
                PACKAGE_MANAGER="zypper"
                ;;
            rocky)
                PLATFORM="rocky"
                PACKAGE_MANAGER="dnf"
                ;;
            almalinux)
                PLATFORM="alma"
                PACKAGE_MANAGER="dnf"
                ;;
            *)
                log_error "Unsupported Linux distribution: $ID"
                log_error "Supported: fedora, ubuntu, debian, gentoo, void, nixos, raspbian, arch, alpine, opensuse, rocky, alma, wsl, termux, chromeos"
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
