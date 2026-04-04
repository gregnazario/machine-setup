#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

REPO_URL="${MACHINE_SETUP_REPO:-https://github.com/yourusername/machine-setup.git}"

main() {
    local remote_host=""
    local profile=""
    local dry_run=false
    local extra_args=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile|-p) profile="$2"; shift 2 ;;
            --dry-run) dry_run=true; shift ;;
            --no-packages|--no-dotfiles|--no-syncthing|--no-backup)
                extra_args+=("$1"); shift ;;
            *)
                if [[ -z "$remote_host" ]]; then
                    remote_host="$1"
                else
                    extra_args+=("$1")
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$remote_host" ]]; then
        echo "Usage: $0 <user@host> [--profile <name>] [--dry-run] [setup.sh options...]"
        exit 1
    fi

    log_info "Remote setup: $remote_host"

    # Test SSH connectivity
    log_info "Testing SSH connection..."
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$remote_host" "echo ok" &>/dev/null; then
        log_error "Cannot connect to $remote_host via SSH"
        log_info "Ensure SSH key authentication is configured"
        exit 1
    fi
    log_success "SSH connection OK"

    # Check if git is available on remote
    log_info "Checking remote prerequisites..."
    if ! ssh "$remote_host" "command -v git" &>/dev/null; then
        log_warn "git not found on remote. Attempting to install..."
        ssh "$remote_host" "sudo apt-get update && sudo apt-get install -y git 2>/dev/null || sudo dnf install -y git 2>/dev/null || sudo pacman -S --noconfirm git 2>/dev/null || true"
    fi

    local args=""
    [[ -n "$profile" ]] && args="$args --profile $profile"
    [[ "$dry_run" == true ]] && args="$args --dry-run"
    for arg in "${extra_args[@]+"${extra_args[@]}"}"; do
        args="$args $arg"
    done

    log_info "Running setup on $remote_host..."
    if [[ "$dry_run" == true ]]; then
        log_info "Would run on $remote_host:"
        echo "  ssh $remote_host 'cd ~/.machine-setup && bash setup.sh $args'"
        return 0
    fi

    ssh -t "$remote_host" "
        export MACHINE_SETUP_REPO='${REPO_URL}'
        if [[ -d ~/.machine-setup/.git ]]; then
            cd ~/.machine-setup
            git pull --ff-only 2>/dev/null || true
        else
            git clone '${REPO_URL}' ~/.machine-setup
            cd ~/.machine-setup
        fi
        bash setup.sh ${args}
    "

    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log_success "Remote setup complete: $remote_host"
    else
        log_error "Remote setup failed on $remote_host (exit code: $exit_code)"
    fi
    return $exit_code
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
