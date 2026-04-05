#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

setup_ssh_agent() {
    log_info "Setting up SSH agent..."
    
    local shell_config=""
    
    if [[ -f "$HOME/.bashrc" ]]; then
        shell_config="$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        shell_config="$HOME/.zshrc"
    elif [[ -f "$HOME/.config/fish/config.fish" ]]; then
        shell_config="$HOME/.config/fish/config.fish"
    else
        log_error "No shell config found"
        exit 1
    fi
    
    if grep -q "SSH_AGENT_PID" "$shell_config"; then
        log_info "SSH agent already configured in $shell_config"
        return
    fi
    
    cat >> "$shell_config" <<'EOF'

# SSH Agent
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval $(ssh-agent -s)
    trap "kill $SSH_AGENT_PID" EXIT
fi
EOF
    
    log_success "SSH agent configured in $shell_config"
    log_info "Restart your shell or run: source $shell_config"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Configure SSH agent auto-start in your shell configuration file.

Options:
    -h, --help    Show this help message
EOF
    exit 0
}

main() {
    case "${1:-}" in
        -h|--help) usage ;;
    esac

    setup_ssh_agent
}

main "$@"
