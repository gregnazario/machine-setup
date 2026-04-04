# Bash completion for setup.sh
_setup_sh() {
    local cur prev opts profiles
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--profile --no-packages --no-dotfiles --no-syncthing --no-backup --dry-run --list-profiles --show-profile --validate-profile --create-profile --unlink --check --status --interactive --help"

    case "$prev" in
        --profile|--show-profile|--validate-profile|-p)
            # Complete with available profile names
            local profile_dir
            if [[ -d "./profiles" ]]; then
                profile_dir="./profiles"
            elif [[ -d "$HOME/.machine-setup/profiles" ]]; then
                profile_dir="$HOME/.machine-setup/profiles"
            fi
            if [[ -n "${profile_dir:-}" ]]; then
                profiles=$(find "$profile_dir" -name "*.conf" -exec basename {} .conf \; 2>/dev/null)
                COMPREPLY=( $(compgen -W "$profiles" -- "$cur") )
            fi
            return 0
            ;;
    esac

    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
    return 0
}

complete -F _setup_sh setup.sh
complete -F _setup_sh ./setup.sh
