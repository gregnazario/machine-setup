#compdef setup.sh

_setup_sh() {
    local -a commands profiles

    commands=(
        '--profile[Profile to use]:profile:_setup_profiles'
        '--no-packages[Skip package installation]'
        '--no-dotfiles[Skip dotfile linking]'
        '--no-syncthing[Skip Syncthing setup]'
        '--no-backup[Skip backup setup]'
        '--dry-run[Show what would be done]'
        '--list-profiles[List available profiles]'
        '--show-profile[Show profile details]:profile:_setup_profiles'
        '--validate-profile[Validate profile config]:profile:_setup_profiles'
        '--create-profile[Create new profile]:name:'
        '--unlink[Remove dotfile symlinks]'
        '--check[Check health of setup]'
        '--status[Show status dashboard]'
        '--interactive[Interactive setup wizard]'
        '--help[Show help message]'
    )

    _arguments -s $commands
}

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

_setup_sh "$@"
