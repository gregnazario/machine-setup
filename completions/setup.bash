# Bash completion for machine-setup
# Source this file or place in ~/.bash_completion.d/

# Helper: list available profiles
_setup_profiles() {
    local profile_dir
    if [[ -d "./profiles" ]]; then
        profile_dir="./profiles"
    elif [[ -d "$HOME/.machine-setup/profiles" ]]; then
        profile_dir="$HOME/.machine-setup/profiles"
    fi
    if [[ -n "${profile_dir:-}" ]]; then
        find "$profile_dir" -name "*.conf" -exec basename {} .conf \; 2>/dev/null
    fi
}

# Helper: list fleet machine names
_setup_fleet_machines() {
    local fleet_file="${HOME}/.machine-setup/fleet.conf"
    if [[ -f "$fleet_file" ]]; then
        grep '^\[machine\.' "$fleet_file" 2>/dev/null | sed 's/\[machine\.\(.*\)\]/\1/'
    fi
}

# Main setup.sh completion
_setup_sh() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--profile --no-packages --no-dotfiles --no-syncthing --no-backup --dry-run --list-profiles --show-profile --validate-profile --create-profile --unlink --check --status --interactive --diff-profiles --secrets --remote --fleet --audit --gpg --verify-backup --detect-conflicts --build-image --serve --update --help"

    case "$prev" in
        --profile|--show-profile|--validate-profile|--build-image|-p)
            COMPREPLY=( $(compgen -W "$(_setup_profiles)" -- "$cur") )
            return 0
            ;;
        --diff-profiles)
            COMPREPLY=( $(compgen -W "$(_setup_profiles)" -- "$cur") )
            return 0
            ;;
        --secrets)
            COMPREPLY=( $(compgen -W "pull push list status init set-provider" -- "$cur") )
            return 0
            ;;
        --fleet)
            COMPREPLY=( $(compgen -W "register remove list setup setup-all" -- "$cur") )
            return 0
            ;;
        --gpg)
            COMPREPLY=( $(compgen -W "import export list status" -- "$cur") )
            return 0
            ;;
        --serve)
            COMPREPLY=( $(compgen -W "--port" -- "$cur") )
            return 0
            ;;
    esac

    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
    return 0
}

# install-packages.sh completion
_install_packages_sh() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        --profile) COMPREPLY=( $(compgen -W "$(_setup_profiles)" -- "$cur") ); return 0 ;;
    esac
    COMPREPLY=( $(compgen -W "--profile --dry-run --help" -- "$cur") )
}

# link-dotfiles.sh completion
_link_dotfiles_sh() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        --profile) COMPREPLY=( $(compgen -W "$(_setup_profiles)" -- "$cur") ); return 0 ;;
    esac
    COMPREPLY=( $(compgen -W "--profile --dry-run --force --help" -- "$cur") )
}

# unlink-dotfiles.sh completion
_unlink_dotfiles_sh() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        --profile) COMPREPLY=( $(compgen -W "$(_setup_profiles)" -- "$cur") ); return 0 ;;
    esac
    COMPREPLY=( $(compgen -W "--profile --dry-run --help" -- "$cur") )
}

# check-health.sh completion
_check_health_sh() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        --profile|-p) COMPREPLY=( $(compgen -W "$(_setup_profiles)" -- "$cur") ); return 0 ;;
    esac
    COMPREPLY=( $(compgen -W "--profile --help" -- "$cur") )
}

# status-dashboard.sh completion
_status_dashboard_sh() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        --profile|-p) COMPREPLY=( $(compgen -W "$(_setup_profiles)" -- "$cur") ); return 0 ;;
    esac
    COMPREPLY=( $(compgen -W "--profile --help" -- "$cur") )
}

# validate-profile.sh completion
_validate_profile_sh() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        --profile) COMPREPLY=( $(compgen -W "$(_setup_profiles)" -- "$cur") ); return 0 ;;
    esac
    COMPREPLY=( $(compgen -W "--profile --help" -- "$cur") )
}

# dry-run-diff.sh completion
_dry_run_diff_sh() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        --profile) COMPREPLY=( $(compgen -W "$(_setup_profiles)" -- "$cur") ); return 0 ;;
    esac
    COMPREPLY=( $(compgen -W "--profile --help" -- "$cur") )
}

# detect-conflicts.sh completion
_detect_conflicts_sh() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        --profile|-p) COMPREPLY=( $(compgen -W "$(_setup_profiles)" -- "$cur") ); return 0 ;;
    esac
    COMPREPLY=( $(compgen -W "--profile --help" -- "$cur") )
}

# diff-profiles.sh completion
_diff_profiles_sh() {
    local cur
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -W "$(_setup_profiles) --help" -- "$cur") )
}

# fleet-manager.sh completion
_fleet_manager_sh() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        setup|remove)
            COMPREPLY=( $(compgen -W "$(_setup_fleet_machines)" -- "$cur") )
            return 0
            ;;
    esac
    COMPREPLY=( $(compgen -W "register remove list setup setup-all --help" -- "$cur") )
}

# remote-setup.sh completion
_remote_setup_sh() {
    local cur
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -W "--profile --dry-run --no-packages --no-dotfiles --no-syncthing --no-backup --help" -- "$cur") )
}

# install-completions.sh completion
_install_completions_sh() {
    local cur
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -W "--all --bash --zsh --fish --dry-run --help" -- "$cur") )
}

# gpg-manager.sh completion
_gpg_manager_sh() {
    local cur
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -W "import export list status --help" -- "$cur") )
}

# web-dashboard.sh completion
_web_dashboard_sh() {
    local cur
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -W "--profile --port --help" -- "$cur") )
}

# build-image.sh completion
_build_image_sh() {
    local cur
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -W "$(_setup_profiles) --help" -- "$cur") )
}

complete -F _setup_sh setup.sh
complete -F _setup_sh ./setup.sh
complete -F _install_packages_sh install-packages.sh
complete -F _install_packages_sh ./scripts/install-packages.sh
complete -F _link_dotfiles_sh link-dotfiles.sh
complete -F _link_dotfiles_sh ./scripts/link-dotfiles.sh
complete -F _unlink_dotfiles_sh unlink-dotfiles.sh
complete -F _unlink_dotfiles_sh ./scripts/unlink-dotfiles.sh
complete -F _check_health_sh check-health.sh
complete -F _check_health_sh ./scripts/check-health.sh
complete -F _status_dashboard_sh status-dashboard.sh
complete -F _status_dashboard_sh ./scripts/status-dashboard.sh
complete -F _validate_profile_sh validate-profile.sh
complete -F _validate_profile_sh ./scripts/validate-profile.sh
complete -F _dry_run_diff_sh dry-run-diff.sh
complete -F _dry_run_diff_sh ./scripts/dry-run-diff.sh
complete -F _detect_conflicts_sh detect-conflicts.sh
complete -F _detect_conflicts_sh ./scripts/detect-conflicts.sh
complete -F _diff_profiles_sh diff-profiles.sh
complete -F _diff_profiles_sh ./scripts/diff-profiles.sh
complete -F _fleet_manager_sh fleet-manager.sh
complete -F _fleet_manager_sh ./scripts/fleet-manager.sh
complete -F _remote_setup_sh remote-setup.sh
complete -F _remote_setup_sh ./scripts/remote-setup.sh
complete -F _install_completions_sh install-completions.sh
complete -F _install_completions_sh ./scripts/install-completions.sh
complete -F _gpg_manager_sh gpg-manager.sh
complete -F _gpg_manager_sh ./scripts/gpg-manager.sh
complete -F _web_dashboard_sh web-dashboard.sh
complete -F _web_dashboard_sh ./scripts/web-dashboard.sh
complete -F _build_image_sh build-image.sh
complete -F _build_image_sh ./scripts/build-image.sh
