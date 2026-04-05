#!/usr/bin/env bats

# Per-platform mock tests for install-packages.sh
# Each test creates mock commands that log calls, then verifies the log.

setup() {
    load '../test_helper'
    MOCK_DIR="$(mktemp -d)"
    LOG_FILE="$MOCK_DIR/install.log"

    # Create mock package manager commands that log calls
    for cmd in apt dnf emerge xbps-install brew pkg winget pacman apk zypper nix-env; do
        cat > "$MOCK_DIR/$cmd" <<MOCK
#!/usr/bin/env bash
echo "$cmd \$*" >> "$LOG_FILE"
MOCK
        chmod +x "$MOCK_DIR/$cmd"
    done

    # Mock sudo to just run the command
    cat > "$MOCK_DIR/sudo" <<'MOCK'
#!/usr/bin/env bash
"$@"
MOCK
    chmod +x "$MOCK_DIR/sudo"

    # Mock wc (used by homebrew for Brewfile line count)
    cat > "$MOCK_DIR/wc" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "-l" ]]; then
    /usr/bin/wc -l
else
    /usr/bin/wc "$@"
fi
MOCK
    chmod +x "$MOCK_DIR/wc"

    export PATH="$MOCK_DIR:$PATH"

    # Reset state that may linger between tests
    unset _COMMON_SH_LOADED 2>/dev/null || true
    export DRY_RUN=false
    export PLATFORM=""
    export PACKAGE_MANAGER=""
    export PROFILE_NAME=""
    export PROFILE_FILE=""

    # Source the scripts
    source "$REPO_ROOT/scripts/platform-detect.sh"
    source "$REPO_ROOT/scripts/ini-parser.sh"
    source "$REPO_ROOT/scripts/profile-loader.sh"
    source "$REPO_ROOT/scripts/install-packages.sh"
}

teardown() {
    rm -rf "$MOCK_DIR"
}

# --------------------------------------------------------------------------
# 1. install_packages_apt
# --------------------------------------------------------------------------
@test "install_packages_apt calls sudo apt install -y with packages" {
    install_packages_apt "curl git vim"
    assert [ -f "$LOG_FILE" ]
    run cat "$LOG_FILE"
    assert_line "apt update"
    assert_line "apt install -y curl git vim"
}

# --------------------------------------------------------------------------
# 2. install_packages_dnf
# --------------------------------------------------------------------------
@test "install_packages_dnf calls sudo dnf install -y with packages" {
    install_packages_dnf "curl git vim"
    run cat "$LOG_FILE"
    assert_line "dnf install -y curl git vim"
}

# --------------------------------------------------------------------------
# 3. install_packages_pacman
# --------------------------------------------------------------------------
@test "install_packages_pacman calls sudo pacman -S --noconfirm --needed with packages" {
    install_packages_pacman "curl git vim"
    run cat "$LOG_FILE"
    assert_line "pacman -S --noconfirm --needed curl git vim"
}

# --------------------------------------------------------------------------
# 4. install_packages_apk
# --------------------------------------------------------------------------
@test "install_packages_apk calls sudo apk add with packages" {
    install_packages_apk "curl git vim"
    run cat "$LOG_FILE"
    assert_line "apk add curl git vim"
}

# --------------------------------------------------------------------------
# 5. install_packages_zypper
# --------------------------------------------------------------------------
@test "install_packages_zypper calls sudo zypper install -y with packages" {
    install_packages_zypper "curl git vim"
    run cat "$LOG_FILE"
    assert_line "zypper install -y curl git vim"
}

# --------------------------------------------------------------------------
# 6. install_packages_homebrew calls brew bundle
# --------------------------------------------------------------------------
@test "install_packages_homebrew calls brew bundle with generated Brewfile" {
    install_packages_homebrew "curl git vim"
    run cat "$LOG_FILE"
    # brew bundle --file=<tmpfile> --no-lock
    assert_line --partial "brew bundle --file="
    assert_line --partial "--no-lock"
}

@test "generate_brewfile produces correct Brewfile lines" {
    run generate_brewfile "curl git vim"
    assert_line 'brew "curl"'
    assert_line 'brew "git"'
    assert_line 'brew "vim"'
}

# --------------------------------------------------------------------------
# 7. install_packages_nix calls nix-env for each package
# --------------------------------------------------------------------------
@test "install_packages_nix calls nix-env -iA for each package" {
    install_packages_nix "curl git"
    run cat "$LOG_FILE"
    assert_line "nix-env -iA nixpkgs.curl"
    assert_line "nix-env -iA nixpkgs.git"
}

# --------------------------------------------------------------------------
# 8. install_packages_termux calls pkg install -y (no sudo)
# --------------------------------------------------------------------------
@test "install_packages_termux calls pkg update and pkg install -y without sudo" {
    install_packages_termux "curl git vim"
    run cat "$LOG_FILE"
    assert_line "pkg update"
    assert_line "pkg install -y curl git vim"
    # Ensure sudo was NOT invoked
    refute_line --partial "sudo"
}

# --------------------------------------------------------------------------
# Additional PM tests: emerge, xbps, pkg (FreeBSD), winget
# --------------------------------------------------------------------------
@test "install_packages_emerge calls sudo emerge --noreplace with packages" {
    install_packages_emerge "curl git vim"
    run cat "$LOG_FILE"
    assert_line "emerge --noreplace curl git vim"
}

@test "install_packages_xbps calls sudo xbps-install -S with packages" {
    install_packages_xbps "curl git vim"
    run cat "$LOG_FILE"
    assert_line "xbps-install -S curl git vim"
}

@test "install_packages_pkg calls sudo pkg install -y with packages" {
    install_packages_pkg "curl git vim"
    run cat "$LOG_FILE"
    assert_line "pkg install -y curl git vim"
}

@test "install_packages_winget calls winget install --id for each package" {
    install_packages_winget "Git.Git Vim.Vim"
    run cat "$LOG_FILE"
    assert_line "winget install --id Git.Git --silent"
    assert_line "winget install --id Vim.Vim --silent"
}

# --------------------------------------------------------------------------
# 9. Dry-run mode outputs "Would install" without calling PM
# --------------------------------------------------------------------------
@test "apt dry-run outputs Would install and does not call apt" {
    DRY_RUN=true
    run install_packages_apt "curl git"
    assert_output --partial "Would install: curl git"
    assert [ ! -f "$LOG_FILE" ]
}

@test "dnf dry-run outputs Would install and does not call dnf" {
    DRY_RUN=true
    run install_packages_dnf "curl git"
    assert_output --partial "Would install: curl git"
    assert [ ! -f "$LOG_FILE" ]
}

@test "pacman dry-run outputs Would install and does not call pacman" {
    DRY_RUN=true
    run install_packages_pacman "curl git"
    assert_output --partial "Would install: curl git"
    assert [ ! -f "$LOG_FILE" ]
}

@test "apk dry-run outputs Would install and does not call apk" {
    DRY_RUN=true
    run install_packages_apk "curl git"
    assert_output --partial "Would install: curl git"
    assert [ ! -f "$LOG_FILE" ]
}

@test "zypper dry-run outputs Would install and does not call zypper" {
    DRY_RUN=true
    run install_packages_zypper "curl git"
    assert_output --partial "Would install: curl git"
    assert [ ! -f "$LOG_FILE" ]
}

@test "homebrew dry-run outputs Would install via Brewfile" {
    DRY_RUN=true
    run install_packages_homebrew "curl git"
    assert_output --partial "Would install via Brewfile:"
    assert_output --partial 'brew "curl"'
    assert_output --partial 'brew "git"'
    assert [ ! -f "$LOG_FILE" ]
}

@test "nix dry-run outputs Would install and does not call nix-env" {
    DRY_RUN=true
    run install_packages_nix "curl git"
    assert_output --partial "Would install: curl git"
    assert [ ! -f "$LOG_FILE" ]
}

@test "termux dry-run outputs Would install and does not call pkg" {
    DRY_RUN=true
    run install_packages_termux "curl git"
    assert_output --partial "Would install: curl git"
    assert [ ! -f "$LOG_FILE" ]
}

@test "emerge dry-run outputs Would install and does not call emerge" {
    DRY_RUN=true
    run install_packages_emerge "curl git"
    assert_output --partial "Would install: curl git"
    assert [ ! -f "$LOG_FILE" ]
}

@test "xbps dry-run outputs Would install and does not call xbps-install" {
    DRY_RUN=true
    run install_packages_xbps "curl git"
    assert_output --partial "Would install: curl git"
    assert [ ! -f "$LOG_FILE" ]
}

@test "pkg dry-run outputs Would install and does not call pkg" {
    DRY_RUN=true
    run install_packages_pkg "curl git"
    assert_output --partial "Would install: curl git"
    assert [ ! -f "$LOG_FILE" ]
}

@test "winget dry-run outputs Would install and does not call winget" {
    DRY_RUN=true
    run install_packages_winget "Git.Git"
    assert_output --partial "Would install: Git.Git"
    assert [ ! -f "$LOG_FILE" ]
}

# --------------------------------------------------------------------------
# 10. install_packages dispatcher routes to correct function
# --------------------------------------------------------------------------
@test "install_packages dispatches to apt when PACKAGE_MANAGER=apt" {
    PACKAGE_MANAGER="apt"
    PLATFORM="ubuntu"
    source "$REPO_ROOT/scripts/version-pin.sh"
    install_packages "curl git"
    run cat "$LOG_FILE"
    assert_line "apt update"
    assert_line "apt install -y curl git"
}

@test "install_packages dispatches to dnf when PACKAGE_MANAGER=dnf" {
    PACKAGE_MANAGER="dnf"
    PLATFORM="fedora"
    source "$REPO_ROOT/scripts/version-pin.sh"
    install_packages "curl git"
    run cat "$LOG_FILE"
    assert_line "dnf install -y curl git"
}

@test "install_packages dispatches to pacman when PACKAGE_MANAGER=pacman" {
    PACKAGE_MANAGER="pacman"
    PLATFORM="arch"
    source "$REPO_ROOT/scripts/version-pin.sh"
    install_packages "curl git"
    run cat "$LOG_FILE"
    assert_line "pacman -S --noconfirm --needed curl git"
}

@test "install_packages dispatches to apk when PACKAGE_MANAGER=apk" {
    PACKAGE_MANAGER="apk"
    PLATFORM="alpine"
    source "$REPO_ROOT/scripts/version-pin.sh"
    install_packages "curl git"
    run cat "$LOG_FILE"
    assert_line "apk add curl git"
}

@test "install_packages dispatches to zypper when PACKAGE_MANAGER=zypper" {
    PACKAGE_MANAGER="zypper"
    PLATFORM="opensuse"
    source "$REPO_ROOT/scripts/version-pin.sh"
    install_packages "curl git"
    run cat "$LOG_FILE"
    assert_line "zypper install -y curl git"
}

@test "install_packages dispatches to homebrew when PACKAGE_MANAGER=homebrew" {
    PACKAGE_MANAGER="homebrew"
    PLATFORM="macos"
    source "$REPO_ROOT/scripts/version-pin.sh"
    install_packages "curl git"
    run cat "$LOG_FILE"
    assert_line --partial "brew bundle --file="
}

@test "install_packages dispatches to nix when PACKAGE_MANAGER=nix" {
    PACKAGE_MANAGER="nix"
    PLATFORM="nixos"
    source "$REPO_ROOT/scripts/version-pin.sh"
    install_packages "curl git"
    run cat "$LOG_FILE"
    assert_line "nix-env -iA nixpkgs.curl"
    assert_line "nix-env -iA nixpkgs.git"
}

@test "install_packages dispatches to termux-pkg when PACKAGE_MANAGER=termux-pkg" {
    PACKAGE_MANAGER="termux-pkg"
    PLATFORM="termux"
    source "$REPO_ROOT/scripts/version-pin.sh"
    install_packages "curl git"
    run cat "$LOG_FILE"
    assert_line "pkg update"
    assert_line "pkg install -y curl git"
}

@test "install_packages dispatches to emerge when PACKAGE_MANAGER=emerge" {
    PACKAGE_MANAGER="emerge"
    PLATFORM="gentoo"
    source "$REPO_ROOT/scripts/version-pin.sh"
    install_packages "curl git"
    run cat "$LOG_FILE"
    assert_line "emerge --noreplace curl git"
}

@test "install_packages dispatches to xbps when PACKAGE_MANAGER=xbps" {
    PACKAGE_MANAGER="xbps"
    PLATFORM="void"
    source "$REPO_ROOT/scripts/version-pin.sh"
    install_packages "curl git"
    run cat "$LOG_FILE"
    assert_line "xbps-install -S curl git"
}

@test "install_packages dispatches to pkg when PACKAGE_MANAGER=pkg" {
    PACKAGE_MANAGER="pkg"
    PLATFORM="freebsd"
    source "$REPO_ROOT/scripts/version-pin.sh"
    install_packages "curl git"
    run cat "$LOG_FILE"
    assert_line "pkg install -y curl git"
}

@test "install_packages dispatches to winget when PACKAGE_MANAGER=winget" {
    PACKAGE_MANAGER="winget"
    PLATFORM="windows"
    source "$REPO_ROOT/scripts/version-pin.sh"
    install_packages "Git.Git Vim.Vim"
    run cat "$LOG_FILE"
    assert_line "winget install --id Git.Git --silent"
    assert_line "winget install --id Vim.Vim --silent"
}

@test "install_packages fails for unsupported package manager" {
    PACKAGE_MANAGER="unknown_pm"
    source "$REPO_ROOT/scripts/version-pin.sh"
    run install_packages "curl"
    assert_failure
    assert_output --partial "Unsupported package manager: unknown_pm"
}

# --------------------------------------------------------------------------
# 11. collect_packages includes platform-specific packages
# --------------------------------------------------------------------------
@test "collect_packages includes packages from platform conf when it exists" {
    # Create a temporary profile and platform conf
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    # Create a minimal profile
    cat > "$tmp_dir/test-profile.conf" <<'CONF'
[packages]
base = curl git
CONF

    # Create a platform packages dir
    mkdir -p "$tmp_dir/platforms"
    cat > "$tmp_dir/platforms/testplatform.conf" <<'CONF'
[packages.base]
packages = platform-specific-pkg
CONF

    # Override SCRIPT_DIR so collect_packages finds our fixtures
    PROFILE_FILE="$tmp_dir/test-profile.conf"
    PROFILE_NAME="test-profile"
    PLATFORM="testplatform"

    # Temporarily override the script dir references
    local orig_script_dir="$SCRIPT_DIR"
    SCRIPT_DIR="$tmp_dir/scripts"
    mkdir -p "$SCRIPT_DIR/../packages/platforms"
    cp "$tmp_dir/platforms/testplatform.conf" "$SCRIPT_DIR/../packages/platforms/"

    # Create a common.conf so get_mapped_package_name works
    mkdir -p "$SCRIPT_DIR/../packages"
    touch "$SCRIPT_DIR/../packages/common.conf"

    run collect_packages
    assert_success
    assert_output --partial "curl"
    assert_output --partial "git"
    assert_output --partial "platform-specific-pkg"

    SCRIPT_DIR="$orig_script_dir"
    rm -rf "$tmp_dir"
}
