#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPLETIONS_DIR="${REPO_DIR}/completions"
DOCS_DIR="${REPO_DIR}/docs"
DRY_RUN="${DRY_RUN:-false}"

install_bash_completion() {
    local target_dirs=(
        "$HOME/.bash_completion.d"
        "$HOME/.local/share/bash-completion/completions"
    )

    # Use XDG if set
    if [[ -n "${XDG_DATA_HOME:-}" ]]; then
        target_dirs=("${XDG_DATA_HOME}/bash-completion/completions" "${target_dirs[@]}")
    fi

    local target_dir=""
    for dir in "${target_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            target_dir="$dir"
            break
        fi
    done

    # Default to first option if none exist
    if [[ -z "$target_dir" ]]; then
        target_dir="${target_dirs[0]}"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "Would install bash completion to: $target_dir/setup.sh"
        return
    fi

    mkdir -p "$target_dir"
    ln -sf "${COMPLETIONS_DIR}/setup.bash" "$target_dir/setup.sh"
    log_success "Bash completion installed: $target_dir/setup.sh"

    # Source it in .bashrc if not already done
    local bashrc="$HOME/.bashrc"
    if [[ -f "$bashrc" ]]; then
        if ! grep -q "bash_completion.d\|bash-completion/completions" "$bashrc" 2>/dev/null; then
            log_info "Add to your .bashrc to enable completions:"
            echo "  for f in ~/.bash_completion.d/*; do source \"\$f\" 2>/dev/null; done"
        fi
    fi
}

install_zsh_completion() {
    local target_dirs=(
        "$HOME/.zsh/completions"
        "$HOME/.local/share/zsh/completions"
    )

    if [[ -n "${XDG_DATA_HOME:-}" ]]; then
        target_dirs=("${XDG_DATA_HOME}/zsh/completions" "${target_dirs[@]}")
    fi

    # Also check fpath for existing completion dirs
    if [[ -n "${FPATH:-}" ]]; then
        local user_fpath
        user_fpath=$(echo "$FPATH" | tr ':' '\n' | grep "$HOME" | head -1 || true)
        if [[ -n "$user_fpath" ]]; then
            target_dirs=("$user_fpath" "${target_dirs[@]}")
        fi
    fi

    local target_dir=""
    for dir in "${target_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            target_dir="$dir"
            break
        fi
    done

    if [[ -z "$target_dir" ]]; then
        target_dir="${target_dirs[0]}"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "Would install zsh completion to: $target_dir/_setup.sh"
        return
    fi

    mkdir -p "$target_dir"
    ln -sf "${COMPLETIONS_DIR}/setup.zsh" "$target_dir/_setup.sh"
    log_success "Zsh completion installed: $target_dir/_setup.sh"

    # Check if the dir is in fpath
    local zshrc="$HOME/.zshrc"
    if [[ -f "$zshrc" ]]; then
        if ! grep -q "$target_dir" "$zshrc" 2>/dev/null; then
            log_info "Add to your .zshrc if not already present:"
            echo "  fpath=(${target_dir} \$fpath)"
            echo "  autoload -Uz compinit && compinit"
        fi
    fi
}

install_fish_completion() {
    local target_dir="${HOME}/.config/fish/completions"

    if [[ "$DRY_RUN" == true ]]; then
        echo "Would install fish completion to: $target_dir/setup.sh.fish"
        return
    fi

    mkdir -p "$target_dir"
    ln -sf "${COMPLETIONS_DIR}/setup.fish" "$target_dir/setup.sh.fish"
    log_success "Fish completion installed: $target_dir/setup.sh.fish"
}

detect_and_install() {
    local current_shell
    current_shell=$(basename "${SHELL:-/bin/bash}")

    log_info "Detected shell: $current_shell"

    case "$current_shell" in
        bash)
            install_bash_completion
            ;;
        zsh)
            install_zsh_completion
            ;;
        fish)
            install_fish_completion
            ;;
        *)
            log_warn "Unknown shell: $current_shell"
            log_info "Available completions in: $COMPLETIONS_DIR"
            log_info "  Bash: source $COMPLETIONS_DIR/setup.bash"
            log_info "  Zsh:  copy $COMPLETIONS_DIR/setup.zsh to fpath"
            log_info "  Fish: copy $COMPLETIONS_DIR/setup.fish to ~/.config/fish/completions/"
            ;;
    esac
}

install_man_pages() {
    local target_dirs=(
        "$HOME/.local/share/man/man1"
    )

    if [[ -n "${XDG_DATA_HOME:-}" ]]; then
        target_dirs=("${XDG_DATA_HOME}/man/man1" "${target_dirs[@]}")
    fi

    local target_dir=""
    for dir in "${target_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            target_dir="$dir"
            break
        fi
    done

    if [[ -z "$target_dir" ]]; then
        target_dir="${target_dirs[0]}"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "Would install man pages to: $target_dir/"
        for manfile in "${DOCS_DIR}"/*.1; do
            [[ -f "$manfile" ]] && echo "  $(basename "$manfile")"
        done
        return
    fi

    mkdir -p "$target_dir"

    local count=0
    for manfile in "${DOCS_DIR}"/*.1; do
        [[ -f "$manfile" ]] || continue
        ln -sf "$manfile" "$target_dir/$(basename "$manfile")"
        ((count++))
    done

    log_success "Installed $count man pages to: $target_dir/"
    log_info "Try: man setup.sh"
}

install_all() {
    log_info "Installing completions for all detected shells..."
    command -v bash &>/dev/null && install_bash_completion
    command -v zsh &>/dev/null && install_zsh_completion
    command -v fish &>/dev/null && install_fish_completion
    install_man_pages
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install shell completions and man pages for machine-setup. Detects the
current shell by default, or install for specific shells.

Options:
    --all           Install completions for all shells and man pages
    --bash          Install bash completions
    --zsh           Install zsh completions
    --fish          Install fish completions
    --man-pages     Install man pages to ~/.local/share/man/man1/
    --dry-run       Show what would be installed without making changes
    -h, --help      Show this help message

Examples:
    $(basename "$0")                  # Auto-detect shell
    $(basename "$0") --all            # All shells + man pages
    $(basename "$0") --zsh --dry-run  # Preview zsh installation
    $(basename "$0") --man-pages      # Install man pages only
EOF
    exit 0
}

main() {
    local all=false
    local mode=""
    # Parse all flags first so --dry-run is order-independent
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) usage ;;
            --all) all=true; shift ;;
            --dry-run) DRY_RUN=true; shift ;;
            --bash) mode="bash"; shift ;;
            --zsh) mode="zsh"; shift ;;
            --fish) mode="fish"; shift ;;
            --man-pages) mode="man"; shift ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 [--all|--bash|--zsh|--fish|--man-pages] [--dry-run]"
                exit 1
                ;;
        esac
    done

    # Execute based on parsed mode
    case "$mode" in
        bash) install_bash_completion ;;
        zsh) install_zsh_completion ;;
        fish) install_fish_completion ;;
        man) install_man_pages ;;
        *)
            if [[ "$all" == true ]]; then
                install_all
            else
                detect_and_install
            fi
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
