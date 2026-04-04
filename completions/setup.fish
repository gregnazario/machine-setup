# Fish completions for setup.sh

# Helper to list profiles
function __setup_profiles
    set -l profile_dir
    if test -d ./profiles
        set profile_dir ./profiles
    else if test -d $HOME/.machine-setup/profiles
        set profile_dir $HOME/.machine-setup/profiles
    else
        return
    end
    for f in $profile_dir/*.conf
        basename $f .conf
    end
end

complete -c setup.sh -l profile -s p -x -a '(__setup_profiles)' -d 'Profile to use'
complete -c setup.sh -l no-packages -d 'Skip package installation'
complete -c setup.sh -l no-dotfiles -d 'Skip dotfile linking'
complete -c setup.sh -l no-syncthing -d 'Skip Syncthing setup'
complete -c setup.sh -l no-backup -d 'Skip backup setup'
complete -c setup.sh -l dry-run -d 'Show what would be done'
complete -c setup.sh -l list-profiles -d 'List available profiles'
complete -c setup.sh -l show-profile -x -a '(__setup_profiles)' -d 'Show profile details'
complete -c setup.sh -l validate-profile -x -a '(__setup_profiles)' -d 'Validate profile config'
complete -c setup.sh -l create-profile -x -d 'Create new profile'
complete -c setup.sh -l unlink -d 'Remove dotfile symlinks'
complete -c setup.sh -l check -d 'Check health of setup'
complete -c setup.sh -l status -d 'Show status dashboard'
complete -c setup.sh -l interactive -d 'Interactive setup wizard'
complete -c setup.sh -l help -s h -d 'Show help'
