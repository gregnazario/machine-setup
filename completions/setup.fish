# Fish completions for machine-setup
# Place in ~/.config/fish/completions/

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

# Helper to list fleet machines
function __setup_fleet_machines
    set -l fleet_file $HOME/.machine-setup/fleet.conf
    if test -f $fleet_file
        grep '^\[machine\.' $fleet_file 2>/dev/null | sed 's/\[machine\.\(.*\)\]/\1/'
    end
end

# ── setup.sh ──
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
complete -c setup.sh -l diff-profiles -x -a '(__setup_profiles)' -d 'Compare two profiles'
complete -c setup.sh -l secrets -x -a 'pull push list status init set-provider' -d 'Manage secrets'
complete -c setup.sh -l remote -x -d 'Run on remote machine (user@host)'
complete -c setup.sh -l fleet -x -a 'register remove list setup setup-all' -d 'Manage fleet'
complete -c setup.sh -l audit -d 'Show audit log entries'
complete -c setup.sh -l gpg -x -a 'import export list status' -d 'Manage GPG keys'
complete -c setup.sh -l verify-backup -d 'Verify backup integrity'
complete -c setup.sh -l detect-conflicts -d 'Detect dotfile conflicts'
complete -c setup.sh -l build-image -x -a '(__setup_profiles)' -d 'Build Docker image'
complete -c setup.sh -l serve -d 'Start web dashboard'
complete -c setup.sh -l update -d 'Pull latest and re-run'
complete -c setup.sh -l interactive -s i -d 'Interactive setup wizard'
complete -c setup.sh -l help -s h -d 'Show help'

# ── install-packages.sh ──
complete -c install-packages.sh -l profile -x -a '(__setup_profiles)' -d 'Profile to use'
complete -c install-packages.sh -l dry-run -d 'Show what would be installed'
complete -c install-packages.sh -l help -s h -d 'Show help'

# ── link-dotfiles.sh ──
complete -c link-dotfiles.sh -l profile -x -a '(__setup_profiles)' -d 'Profile to use'
complete -c link-dotfiles.sh -l dry-run -d 'Show what would be linked'
complete -c link-dotfiles.sh -l force -d 'Overwrite without backup'
complete -c link-dotfiles.sh -l help -s h -d 'Show help'

# ── unlink-dotfiles.sh ──
complete -c unlink-dotfiles.sh -l profile -x -a '(__setup_profiles)' -d 'Profile to use'
complete -c unlink-dotfiles.sh -l dry-run -d 'Show what would be removed'
complete -c unlink-dotfiles.sh -l help -s h -d 'Show help'

# ── check-health.sh ──
complete -c check-health.sh -l profile -s p -x -a '(__setup_profiles)' -d 'Profile to check'
complete -c check-health.sh -l help -s h -d 'Show help'

# ── status-dashboard.sh ──
complete -c status-dashboard.sh -l profile -s p -x -a '(__setup_profiles)' -d 'Profile to display'
complete -c status-dashboard.sh -l help -s h -d 'Show help'

# ── validate-profile.sh ──
complete -c validate-profile.sh -l profile -x -a '(__setup_profiles)' -d 'Profile to validate'
complete -c validate-profile.sh -l help -s h -d 'Show help'

# ── dry-run-diff.sh ──
complete -c dry-run-diff.sh -l profile -x -a '(__setup_profiles)' -d 'Profile to diff'
complete -c dry-run-diff.sh -l help -s h -d 'Show help'

# ── detect-conflicts.sh ──
complete -c detect-conflicts.sh -l profile -s p -x -a '(__setup_profiles)' -d 'Profile to check'
complete -c detect-conflicts.sh -l help -s h -d 'Show help'

# ── diff-profiles.sh ──
complete -c diff-profiles.sh -x -a '(__setup_profiles)' -d 'Profile name'
complete -c diff-profiles.sh -l help -s h -d 'Show help'

# ── fleet-manager.sh ──
complete -c fleet-manager.sh -x -a 'register remove list setup setup-all' -d 'Fleet action'
complete -c fleet-manager.sh -l help -s h -d 'Show help'

# ── remote-setup.sh ──
complete -c remote-setup.sh -l profile -x -a '(__setup_profiles)' -d 'Profile to use'
complete -c remote-setup.sh -l dry-run -d 'Show what would be done'
complete -c remote-setup.sh -l no-packages -d 'Skip packages'
complete -c remote-setup.sh -l no-dotfiles -d 'Skip dotfiles'
complete -c remote-setup.sh -l no-syncthing -d 'Skip Syncthing'
complete -c remote-setup.sh -l no-backup -d 'Skip backup'
complete -c remote-setup.sh -l help -s h -d 'Show help'

# ── install-completions.sh ──
complete -c install-completions.sh -l all -d 'Install for all shells'
complete -c install-completions.sh -l bash -d 'Install bash completions'
complete -c install-completions.sh -l zsh -d 'Install zsh completions'
complete -c install-completions.sh -l fish -d 'Install fish completions'
complete -c install-completions.sh -l dry-run -d 'Show what would be done'
complete -c install-completions.sh -l help -s h -d 'Show help'

# ── gpg-manager.sh ──
complete -c gpg-manager.sh -x -a 'import export list status' -d 'GPG action'
complete -c gpg-manager.sh -l help -s h -d 'Show help'

# ── web-dashboard.sh ──
complete -c web-dashboard.sh -l profile -x -a '(__setup_profiles)' -d 'Profile to display'
complete -c web-dashboard.sh -l port -x -d 'Port number'
complete -c web-dashboard.sh -l help -s h -d 'Show help'

# ── build-image.sh ──
complete -c build-image.sh -x -a '(__setup_profiles)' -d 'Profile to build'
complete -c build-image.sh -l help -s h -d 'Show help'
