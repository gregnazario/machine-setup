#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/lib/common.sh"

DRY_RUN=false

HERMES_INSTALL_URL="https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install and configure the Hermes AI agent by Nous Research.

Handles platform verification, installation via curl, backend selection
(Nous Portal / OpenRouter / custom endpoint), and optional messaging
gateway setup (Telegram, Discord, Slack, WhatsApp, Signal, Email).

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
    if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
        log_info "Platform '$PLATFORM' is supported by Hermes"
        return 0
    else
        log_warn "Hermes does not officially support platform '$PLATFORM'"
        log_warn "Supported: Linux, macOS, WSL2. Skipping Hermes setup."
        exit 0
    fi
}

check_installed() {
    if command -v hermes &> /dev/null; then
        return 0
    fi
    return 1
}

install_hermes() {
    if check_installed; then
        log_info "Hermes is already installed"
        read -p "Update Hermes to the latest version? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[dry-run] Would run: hermes update"
            else
                hermes update
                log_success "Hermes updated"
            fi
        fi
        return 0
    fi

    log_info "Installing Hermes..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] Would run: curl -fsSL $HERMES_INSTALL_URL | bash"
        return 0
    fi

    curl -fsSL "$HERMES_INSTALL_URL" | bash
    log_success "Hermes installed"
}

select_backend() {
    echo ""
    log_info "Select a backend for Hermes:"
    echo "  1) Nous Portal (OAuth - no API key needed)"
    echo "  2) OpenRouter (requires API key)"
    echo "  3) Custom OpenAI-compatible endpoint"
    echo ""
    read -p "Choose [1-3]: " -n 1 -r
    echo ""

    case "$REPLY" in
        1) HERMES_BACKEND="nous" ;;
        2) HERMES_BACKEND="openrouter" ;;
        3) HERMES_BACKEND="custom" ;;
        *)
            log_warn "Invalid choice, defaulting to Nous Portal"
            HERMES_BACKEND="nous"
            ;;
    esac

    log_info "Selected backend: $HERMES_BACKEND"
}

select_gateways() {
    HERMES_GATEWAYS=()
    echo ""
    log_info "Select messaging gateways to configure (enter numbers separated by spaces, or 'none'):"
    echo "  1) Telegram"
    echo "  2) Discord"
    echo "  3) Slack"
    echo "  4) WhatsApp"
    echo "  5) Signal"
    echo "  6) Email"
    echo ""
    read -p "Choose (e.g., '1 3' or 'none'): " -r

    if [[ "$REPLY" == "none" ]] || [[ -z "$REPLY" ]]; then
        log_info "No gateways selected"
        return 0
    fi

    for choice in $REPLY; do
        case "$choice" in
            1) HERMES_GATEWAYS+=("telegram") ;;
            2) HERMES_GATEWAYS+=("discord") ;;
            3) HERMES_GATEWAYS+=("slack") ;;
            4) HERMES_GATEWAYS+=("whatsapp") ;;
            5) HERMES_GATEWAYS+=("signal") ;;
            6) HERMES_GATEWAYS+=("email") ;;
            *) log_warn "Ignoring invalid choice: $choice" ;;
        esac
    done

    if [[ ${#HERMES_GATEWAYS[@]} -gt 0 ]]; then
        log_info "Selected gateways: ${HERMES_GATEWAYS[*]}"
    fi
}

run_native_setup() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] Would run: hermes setup"
        if [[ ${#HERMES_GATEWAYS[@]} -gt 0 ]]; then
            log_info "[dry-run] Would run: hermes gateway setup"
        fi
        return 0
    fi

    log_info "Launching Hermes native setup wizard..."
    log_info "Backend choice: $HERMES_BACKEND"
    hermes setup

    if [[ ${#HERMES_GATEWAYS[@]} -gt 0 ]]; then
        log_info "Launching Hermes gateway setup..."
        hermes gateway setup
    fi
}

register_dotfiles() {
    local config_dir="$HOME/.config/hermes"
    if [[ -d "$config_dir" ]]; then
        log_info "Hermes config directory found at $config_dir"
        log_success "Config will be synced/backed up via dotfile linking"
    else
        log_info "Hermes config directory will be created during native setup"
    fi
}

main() {
    case "${1:-}" in
        -h|--help) usage ;;
        --dry-run) DRY_RUN=true ;;
    esac

    log_info "=== Hermes Agent Setup ==="

    check_platform
    install_hermes
    select_backend
    select_gateways
    run_native_setup
    register_dotfiles

    log_success "Hermes setup complete!"
}

main "$@"
