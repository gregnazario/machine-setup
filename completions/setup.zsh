#compdef setup.sh

# Zsh completions for machine-setup
# Place in your fpath or source directly

_setup_profiles() {
    local profile_dir
    if [[ -d "./profiles" ]]; then
        profile_dir="./profiles"
    elif [[ -d "$HOME/.machine-setup/profiles" ]]; then
        profile_dir="$HOME/.machine-setup/profiles"
    else
        return
    fi

    local -a profiles
    profiles=(${(f)"$(find "$profile_dir" -name '*.conf' -exec basename {} .conf \;)"})
    _describe 'profile' profiles
}

_setup_fleet_machines() {
    local fleet_file="${HOME}/.machine-setup/fleet.conf"
    if [[ -f "$fleet_file" ]]; then
        local -a machines
        machines=(${(f)"$(grep '^\[machine\.' "$fleet_file" 2>/dev/null | sed 's/\[machine\.\(.*\)\]/\1/')"})
        _describe 'machine' machines
    fi
}

_setup_sh() {
    _arguments -s \
        '(-p --profile)'{-p,--profile}'[Profile to use]:profile:_setup_profiles' \
        '--no-packages[Skip package installation]' \
        '--no-dotfiles[Skip dotfile linking]' \
        '--no-syncthing[Skip Syncthing setup]' \
        '--no-backup[Skip backup setup]' \
        '--dry-run[Show what would be done]' \
        '--list-profiles[List available profiles]' \
        '--show-profile[Show profile details]:profile:_setup_profiles' \
        '--validate-profile[Validate profile config]:profile:_setup_profiles' \
        '--create-profile[Create new profile]:name:' \
        '--unlink[Remove dotfile symlinks]' \
        '--check[Check health of setup]' \
        '--status[Show status dashboard]' \
        '--diff-profiles[Compare two profiles]:profile:_setup_profiles' \
        '--secrets[Manage secrets]:action:(pull push list status init set-provider)' \
        '--remote[Run on remote machine]:user@host:_hosts' \
        '--fleet[Manage fleet]:action:(register remove list setup setup-all)' \
        '--audit[Show audit log entries]:count:' \
        '--gpg[Manage GPG keys]:action:(import export list status)' \
        '--verify-backup[Verify backup integrity]' \
        '--detect-conflicts[Detect dotfile conflicts]' \
        '--build-image[Build Docker image]:profile:_setup_profiles' \
        '--serve[Start web dashboard]' \
        '--update[Pull latest and re-run]' \
        '(-i --interactive)'{-i,--interactive}'[Interactive setup wizard]' \
        '(-h --help)'{-h,--help}'[Show help message]'
}

# Sub-script completions

_install_packages_sh() {
    _arguments -s \
        '--profile[Profile to use]:profile:_setup_profiles' \
        '--dry-run[Show what would be installed]' \
        '(-h --help)'{-h,--help}'[Show help message]'
}

_link_dotfiles_sh() {
    _arguments -s \
        '--profile[Profile to use]:profile:_setup_profiles' \
        '--dry-run[Show what would be linked]' \
        '--force[Overwrite existing files without backup]' \
        '(-h --help)'{-h,--help}'[Show help message]'
}

_unlink_dotfiles_sh() {
    _arguments -s \
        '--profile[Profile to use]:profile:_setup_profiles' \
        '--dry-run[Show what would be removed]' \
        '(-h --help)'{-h,--help}'[Show help message]'
}

_check_health_sh() {
    _arguments -s \
        '(-p --profile)'{-p,--profile}'[Profile to check]:profile:_setup_profiles' \
        '(-h --help)'{-h,--help}'[Show help message]'
}

_status_dashboard_sh() {
    _arguments -s \
        '(-p --profile)'{-p,--profile}'[Profile to display]:profile:_setup_profiles' \
        '(-h --help)'{-h,--help}'[Show help message]'
}

_validate_profile_sh() {
    _arguments -s \
        '--profile[Profile to validate]:profile:_setup_profiles' \
        '(-h --help)'{-h,--help}'[Show help message]'
}

_dry_run_diff_sh() {
    _arguments -s \
        '--profile[Profile to diff]:profile:_setup_profiles' \
        '(-h --help)'{-h,--help}'[Show help message]'
}

_detect_conflicts_sh() {
    _arguments -s \
        '(-p --profile)'{-p,--profile}'[Profile to check]:profile:_setup_profiles' \
        '(-h --help)'{-h,--help}'[Show help message]'
}

_diff_profiles_sh() {
    _arguments -s \
        '(-h --help)'{-h,--help}'[Show help message]' \
        ':first profile:_setup_profiles' \
        ':second profile:_setup_profiles'
}

_fleet_manager_sh() {
    local -a subcommands
    subcommands=(
        'register:Register a new machine'
        'remove:Remove a machine'
        'list:List registered machines'
        'setup:Run setup on a machine'
        'setup-all:Run setup on all machines'
    )

    _arguments -s \
        '(-h --help)'{-h,--help}'[Show help message]' \
        '1:action:_describe "subcommand" subcommands' \
        '*::arg:->args'

    case $state in
        args)
            case ${words[1]} in
                setup|remove) _setup_fleet_machines ;;
                register) _hosts ;;
            esac
            ;;
    esac
}

_remote_setup_sh() {
    _arguments -s \
        '--profile[Profile to use]:profile:_setup_profiles' \
        '--dry-run[Show what would be done]' \
        '--no-packages[Skip packages]' \
        '--no-dotfiles[Skip dotfiles]' \
        '--no-syncthing[Skip Syncthing]' \
        '--no-backup[Skip backup]' \
        '(-h --help)'{-h,--help}'[Show help message]' \
        ':remote host:_hosts'
}

_install_completions_sh() {
    _arguments -s \
        '--all[Install for all shells]' \
        '--bash[Install bash completions]' \
        '--zsh[Install zsh completions]' \
        '--fish[Install fish completions]' \
        '--dry-run[Show what would be done]' \
        '(-h --help)'{-h,--help}'[Show help message]'
}

_gpg_manager_sh() {
    _arguments -s \
        '(-h --help)'{-h,--help}'[Show help message]' \
        '1:action:(import export list status)'
}

_web_dashboard_sh() {
    _arguments -s \
        '--profile[Profile to display]:profile:_setup_profiles' \
        '--port[Port number]:port:' \
        '(-h --help)'{-h,--help}'[Show help message]'
}

_build_image_sh() {
    _arguments -s \
        '(-h --help)'{-h,--help}'[Show help message]' \
        ':profile:_setup_profiles'
}

# Register completions
compdef _setup_sh setup.sh
compdef _install_packages_sh install-packages.sh
compdef _link_dotfiles_sh link-dotfiles.sh
compdef _unlink_dotfiles_sh unlink-dotfiles.sh
compdef _check_health_sh check-health.sh
compdef _status_dashboard_sh status-dashboard.sh
compdef _validate_profile_sh validate-profile.sh
compdef _dry_run_diff_sh dry-run-diff.sh
compdef _detect_conflicts_sh detect-conflicts.sh
compdef _diff_profiles_sh diff-profiles.sh
compdef _fleet_manager_sh fleet-manager.sh
compdef _remote_setup_sh remote-setup.sh
compdef _install_completions_sh install-completions.sh
compdef _gpg_manager_sh gpg-manager.sh
compdef _web_dashboard_sh web-dashboard.sh
compdef _build_image_sh build-image.sh
