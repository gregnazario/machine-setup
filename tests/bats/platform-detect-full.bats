#!/usr/bin/env bats
# Mock-based tests for all platform detection paths in scripts/platform-detect.sh

setup() {
    load '../test_helper'
    MOCK_DIR="$(mktemp -d)"
    TEST_ROOT="$(mktemp -d)"
    source "$REPO_ROOT/scripts/lib/common.sh"
}

teardown() {
    rm -rf "$MOCK_DIR" "$TEST_ROOT"
}

# Helper: run platform detection with mocked uname and os-release
# Usage: detect_with_mock <uname_output> [os_release_id] [uname_r_output] [extra_env]
detect_with_mock() {
    local mock_uname="$1"
    local mock_os_release_id="${2:-}"
    local mock_uname_r="${3:-5.15.0-generic}"
    local extra_env="${4:-}"

    # Create mock uname
    cat > "$MOCK_DIR/uname" <<MOCK
#!/usr/bin/env bash
case "\$1" in
    -r) echo "$mock_uname_r" ;;
    -s) echo "$mock_uname" ;;
    "") echo "$mock_uname" ;;
    *)  echo "$mock_uname" ;;
esac
MOCK
    chmod +x "$MOCK_DIR/uname"

    # Create a fake /etc/os-release if an ID is provided
    local fake_etc="$TEST_ROOT/etc"
    mkdir -p "$fake_etc"
    if [[ -n "$mock_os_release_id" ]]; then
        echo "ID=$mock_os_release_id" > "$fake_etc/os-release"
        echo "VERSION_CODENAME=test" >> "$fake_etc/os-release"
    else
        rm -f "$fake_etc/os-release"
    fi

    # Create a modified copy of platform-detect.sh that reads from our fake os-release
    local script="$MOCK_DIR/detect.sh"
    local fake_cros="$TEST_ROOT/dev/.cros_milestone"
    sed \
        -e "s|/etc/os-release|$fake_etc/os-release|g" \
        -e "s|/dev/.cros_milestone|$fake_cros|g" \
        "$REPO_ROOT/scripts/platform-detect.sh" > "$script"

    # Also create a lib/ directory with common.sh so the source line resolves
    mkdir -p "$MOCK_DIR/lib"
    cp "$REPO_ROOT/scripts/lib/common.sh" "$MOCK_DIR/lib/common.sh"

    PATH="$MOCK_DIR:$PATH" env $extra_env bash -c "
        source '$script'
        detect_platform
        echo \"\$PLATFORM|\$PACKAGE_MANAGER\"
    "
}

# ---------------------------------------------------------------------------
# 1. macOS
# ---------------------------------------------------------------------------
@test "platform-detect: macOS detected from uname=Darwin" {
    run detect_with_mock "Darwin"
    assert_success
    assert_line "macos|homebrew"
}

# ---------------------------------------------------------------------------
# 2. FreeBSD
# ---------------------------------------------------------------------------
@test "platform-detect: FreeBSD detected from uname=FreeBSD" {
    run detect_with_mock "FreeBSD"
    assert_success
    assert_line "freebsd|pkg"
}

# ---------------------------------------------------------------------------
# 3. WSL (uname -r contains 'microsoft')
# ---------------------------------------------------------------------------
@test "platform-detect: WSL detected from uname -r containing microsoft" {
    run detect_with_mock "Linux" "" "5.15.153.1-microsoft-standard-WSL2"
    assert_success
    assert_line "wsl|apt"
}

# ---------------------------------------------------------------------------
# 4. Windows (Git Bash / MINGW)
# ---------------------------------------------------------------------------
@test "platform-detect: Windows detected from uname=MINGW64_NT" {
    run detect_with_mock "MINGW64_NT-10.0"
    assert_success
    assert_line "windows|winget"
}

@test "platform-detect: Windows detected from uname=MSYS_NT" {
    run detect_with_mock "MSYS_NT-10.0"
    assert_success
    assert_line "windows|winget"
}

@test "platform-detect: Windows detected from uname=CYGWIN_NT" {
    run detect_with_mock "CYGWIN_NT-10.0"
    assert_success
    assert_line "windows|winget"
}

# ---------------------------------------------------------------------------
# 5. Termux (ANDROID_ROOT set)
# ---------------------------------------------------------------------------
@test "platform-detect: Termux detected via ANDROID_ROOT" {
    run detect_with_mock "Linux" "" "5.15.0-generic" "ANDROID_ROOT=/system"
    assert_success
    assert_line "termux|termux-pkg"
}

@test "platform-detect: Termux detected via PREFIX containing com.termux" {
    run detect_with_mock "Linux" "" "5.15.0-generic" "PREFIX=/data/data/com.termux/files/usr"
    assert_success
    assert_line "termux|termux-pkg"
}

# ---------------------------------------------------------------------------
# 6. ChromeOS (cros_milestone file exists)
# ---------------------------------------------------------------------------
@test "platform-detect: ChromeOS detected via cros_milestone" {
    # Create the fake cros_milestone file at the path our patched script looks for
    mkdir -p "$TEST_ROOT/dev"
    echo "120" > "$TEST_ROOT/dev/.cros_milestone"

    run detect_with_mock "Linux" "" "5.15.0-generic"
    assert_success
    assert_line "chromeos|apt"
}

# ---------------------------------------------------------------------------
# 7. Fedora
# ---------------------------------------------------------------------------
@test "platform-detect: Fedora detected from ID=fedora" {
    run detect_with_mock "Linux" "fedora"
    assert_success
    assert_line "fedora|dnf"
}

# ---------------------------------------------------------------------------
# 8. Ubuntu
# ---------------------------------------------------------------------------
@test "platform-detect: Ubuntu detected from ID=ubuntu" {
    run detect_with_mock "Linux" "ubuntu"
    assert_success
    assert_line "ubuntu|apt"
}

# ---------------------------------------------------------------------------
# 9. Debian
# ---------------------------------------------------------------------------
@test "platform-detect: Debian detected from ID=debian" {
    run detect_with_mock "Linux" "debian"
    assert_success
    assert_line "debian|apt"
}

# ---------------------------------------------------------------------------
# 10. Raspbian
# ---------------------------------------------------------------------------
@test "platform-detect: Raspbian detected from ID=raspbian" {
    run detect_with_mock "Linux" "raspbian"
    assert_success
    assert_line "raspberrypios|apt"
}

# ---------------------------------------------------------------------------
# 11. Gentoo
# ---------------------------------------------------------------------------
@test "platform-detect: Gentoo detected from ID=gentoo" {
    run detect_with_mock "Linux" "gentoo"
    assert_success
    assert_line "gentoo|emerge"
}

# ---------------------------------------------------------------------------
# 12. Void
# ---------------------------------------------------------------------------
@test "platform-detect: Void detected from ID=void" {
    run detect_with_mock "Linux" "void"
    assert_success
    assert_line "void|xbps"
}

# ---------------------------------------------------------------------------
# 13. Arch
# ---------------------------------------------------------------------------
@test "platform-detect: Arch detected from ID=arch" {
    run detect_with_mock "Linux" "arch"
    assert_success
    assert_line "arch|pacman"
}

# ---------------------------------------------------------------------------
# 14. Alpine
# ---------------------------------------------------------------------------
@test "platform-detect: Alpine detected from ID=alpine" {
    run detect_with_mock "Linux" "alpine"
    assert_success
    assert_line "alpine|apk"
}

# ---------------------------------------------------------------------------
# 15. OpenSUSE
# ---------------------------------------------------------------------------
@test "platform-detect: OpenSUSE Tumbleweed detected from ID=opensuse-tumbleweed" {
    run detect_with_mock "Linux" "opensuse-tumbleweed"
    assert_success
    assert_line "opensuse|zypper"
}

# ---------------------------------------------------------------------------
# 16. Rocky
# ---------------------------------------------------------------------------
@test "platform-detect: Rocky detected from ID=rocky" {
    run detect_with_mock "Linux" "rocky"
    assert_success
    assert_line "rocky|dnf"
}

# ---------------------------------------------------------------------------
# 17. AlmaLinux
# ---------------------------------------------------------------------------
@test "platform-detect: AlmaLinux detected from ID=almalinux" {
    run detect_with_mock "Linux" "almalinux"
    assert_success
    assert_line "alma|dnf"
}

# ---------------------------------------------------------------------------
# 18. NixOS
# ---------------------------------------------------------------------------
@test "platform-detect: NixOS detected from ID=nixos" {
    run detect_with_mock "Linux" "nixos"
    assert_success
    assert_line "nixos|nix"
}

# ---------------------------------------------------------------------------
# 19. Unsupported distro exits with error
# ---------------------------------------------------------------------------
@test "platform-detect: unsupported distro exits with error" {
    run detect_with_mock "Linux" "unknowndistro"
    assert_failure
    assert_output --partial "Unsupported Linux distribution"
}

# ---------------------------------------------------------------------------
# 20. Derived distros mapped to their parent
# ---------------------------------------------------------------------------
@test "platform-detect: Pop!_OS (ID=pop) maps to ubuntu|apt" {
    run detect_with_mock "Linux" "pop"
    assert_success
    assert_line "ubuntu|apt"
}

@test "platform-detect: Linux Mint (ID=linuxmint) maps to ubuntu|apt" {
    run detect_with_mock "Linux" "linuxmint"
    assert_success
    assert_line "ubuntu|apt"
}

@test "platform-detect: Manjaro (ID=manjaro) maps to arch|pacman" {
    run detect_with_mock "Linux" "manjaro"
    assert_success
    assert_line "arch|pacman"
}

@test "platform-detect: EndeavourOS (ID=endeavouros) maps to arch|pacman" {
    run detect_with_mock "Linux" "endeavouros"
    assert_success
    assert_line "arch|pacman"
}

@test "platform-detect: Garuda (ID=garuda) maps to arch|pacman" {
    run detect_with_mock "Linux" "garuda"
    assert_success
    assert_line "arch|pacman"
}

# ---------------------------------------------------------------------------
# 21. No /etc/os-release and not a known uname → exits with error
# ---------------------------------------------------------------------------
@test "platform-detect: unknown platform with no os-release exits with error" {
    run detect_with_mock "Linux" ""
    assert_failure
    assert_output --partial "Unable to detect platform"
}
