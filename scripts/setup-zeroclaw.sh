#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/lib/common.sh"

DRY_RUN=false

ZEROCLAW_INSTALL_URL="https://zeroclawlabs.ai/install.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install and configure the Zeroclaw AI agent by Zeroclaw Labs.

Handles platform verification, installation via curl, backend selection
(Claude / OpenAI / local models), and optional messaging gateway setup
(Telegram, Discord, WhatsApp, Slack).

Options:
    --dry-run     Show what would be done without executing
    -h, --help    Show this help message
EOF
    exit 0
}

is_linux_platform() {
    local p="$1"
    case "$p" in
        fedora|ubuntu|debian|arch|gentoo|void|alpine|opensuse|rocky|alma|raspberrypios|nixos|chromeos)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

check_platform() {
    detect_platform
    if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "windows" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
        log_info "Platform '$PLATFORM' is supported by Zeroclaw"
        return 0
    else
        log_warn "Zeroclaw does not officially support platform '$PLATFORM'"
        log_warn "Supported: Linux, macOS, Windows, WSL2. Skipping Zeroclaw setup."
        exit 0
    fi
}

check_installed() {
    if command -v zeroclaw &> /dev/null; then
        return 0
    fi
    return 1
}

install_zeroclaw() {
    if check_installed; then
        log_info "Zeroclaw is already installed"
        read -p "Reinstall Zeroclaw? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing installation"
            return 0
        fi
    fi

    log_info "Installing Zeroclaw..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] Would run: curl -fsSL $ZEROCLAW_INSTALL_URL | bash"
        return 0
    fi

    curl -fsSL "$ZEROCLAW_INSTALL_URL" | bash
    log_success "Zeroclaw installed"
}

select_backend() {
    echo ""
    log_info "Select a backend for Zeroclaw:"
    echo "  1) Claude (Anthropic API key required)"
    echo "  2) OpenAI (API key required)"
    echo "  3) Local models (no API key needed)"
    echo ""
    read -p "Choose [1-3]: " -n 1 -r
    echo ""

    case "$REPLY" in
        1) ZEROCLAW_BACKEND="claude" ;;
        2) ZEROCLAW_BACKEND="openai" ;;
        3) ZEROCLAW_BACKEND="local" ;;
        *)
            log_warn "Invalid choice, defaulting to Claude"
            ZEROCLAW_BACKEND="claude"
            ;;
    esac

    log_info "Selected backend: $ZEROCLAW_BACKEND"
}

select_gateways() {
    ZEROCLAW_GATEWAYS=()
    echo ""
    log_info "Select messaging gateways to configure (enter numbers separated by spaces, or 'none'):"
    echo "  1) Telegram"
    echo "  2) Discord"
    echo "  3) WhatsApp"
    echo "  4) Slack"
    echo ""
    read -p "Choose (e.g., '1 3' or 'none'): " -r

    if [[ "$REPLY" == "none" ]] || [[ -z "$REPLY" ]]; then
        log_info "No gateways selected"
        return 0
    fi

    for choice in $REPLY; do
        case "$choice" in
            1) ZEROCLAW_GATEWAYS+=("telegram") ;;
            2) ZEROCLAW_GATEWAYS+=("discord") ;;
            3) ZEROCLAW_GATEWAYS+=("whatsapp") ;;
            4) ZEROCLAW_GATEWAYS+=("slack") ;;
            *) log_warn "Ignoring invalid choice: $choice" ;;
        esac
    done

    if [[ ${#ZEROCLAW_GATEWAYS[@]} -gt 0 ]]; then
        log_info "Selected gateways: ${ZEROCLAW_GATEWAYS[*]}"
    fi
}

run_native_setup() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] Would run: zeroclaw setup"
        return 0
    fi

    log_info "Launching Zeroclaw native setup wizard..."
    log_info "Backend choice: $ZEROCLAW_BACKEND"
    zeroclaw setup
}

register_dotfiles() {
    local config_dir="$HOME/.config/zeroclaw"
    if [[ -d "$config_dir" ]]; then
        log_info "Zeroclaw config directory found at $config_dir"
        log_success "Config will be synced/backed up via dotfile linking"
    else
        log_info "Zeroclaw config directory will be created during native setup"
    fi
}

main() {
    case "${1:-}" in
        -h|--help) usage ;;
        --dry-run) DRY_RUN=true ;;
    esac

    log_info "=== Zeroclaw Agent Setup ==="

    check_platform
    install_zeroclaw
    select_backend
    select_gateways
    run_native_setup
    register_dotfiles

    log_success "Zeroclaw setup complete!"
}

main "$@"
