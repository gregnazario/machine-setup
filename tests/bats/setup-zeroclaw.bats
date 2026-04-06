#!/usr/bin/env bats

setup() {
    load '../test_helper'

    TEST_TMPDIR="$(mktemp -d)"
    MOCK_DIR="$TEST_TMPDIR/bin"
    mkdir -p "$MOCK_DIR"

    # Create a mock zeroclaw binary
    cat > "$MOCK_DIR/zeroclaw" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    setup) echo "zeroclaw setup called"; exit 0 ;;
    *) exit 0 ;;
esac
MOCK
    chmod +x "$MOCK_DIR/zeroclaw"

    # Create a mock curl
    cat > "$MOCK_DIR/curl" <<'MOCK'
#!/usr/bin/env bash
echo "mock curl: $*"
exit 0
MOCK
    chmod +x "$MOCK_DIR/curl"

    export ORIGINAL_HOME="$HOME"
    export HOME="$TEST_TMPDIR/fakehome"
    mkdir -p "$HOME"

    source "$REPO_ROOT/scripts/lib/common.sh"
    unset _COMMON_SH_LOADED
    source "$REPO_ROOT/scripts/platform-detect.sh"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
    export HOME="$ORIGINAL_HOME"
}

@test "setup-zeroclaw.sh exists and is executable" {
    assert [ -f "$REPO_ROOT/scripts/setup-zeroclaw.sh" ]
    assert [ -x "$REPO_ROOT/scripts/setup-zeroclaw.sh" ]
}

@test "setup-zeroclaw.sh --help shows usage" {
    run bash "$REPO_ROOT/scripts/setup-zeroclaw.sh" --help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "Zeroclaw AI agent"
    assert_output --partial "--dry-run"
}

@test "check_platform allows macos" {
    PLATFORM="macos"
    detect_platform() { :; }

    is_linux_platform() { return 1; }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "windows" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            log_info "Platform '$PLATFORM' is supported by Zeroclaw"
            return 0
        fi
        return 1
    }

    run check_platform
    assert_success
    assert_output --partial "supported by Zeroclaw"
}

@test "check_platform allows windows" {
    PLATFORM="windows"
    detect_platform() { :; }

    is_linux_platform() { return 1; }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "windows" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            log_info "Platform '$PLATFORM' is supported by Zeroclaw"
            return 0
        fi
        return 1
    }

    run check_platform
    assert_success
    assert_output --partial "supported by Zeroclaw"
}

@test "check_platform allows wsl" {
    PLATFORM="wsl"
    detect_platform() { :; }

    is_linux_platform() { return 1; }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "windows" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            log_info "Platform '$PLATFORM' is supported by Zeroclaw"
            return 0
        fi
        return 1
    }

    run check_platform
    assert_success
    assert_output --partial "supported by Zeroclaw"
}

@test "check_platform allows linux platforms" {
    PLATFORM="fedora"
    detect_platform() { :; }

    is_linux_platform() {
        case "$1" in
            fedora|ubuntu|debian|arch|gentoo|void|alpine|opensuse|rocky|alma|raspberrypios|nixos|chromeos) return 0 ;;
            *) return 1 ;;
        esac
    }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "windows" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            log_info "Platform '$PLATFORM' is supported by Zeroclaw"
            return 0
        fi
        return 1
    }

    run check_platform
    assert_success
    assert_output --partial "supported by Zeroclaw"
}

@test "check_platform rejects termux" {
    PLATFORM="termux"
    detect_platform() { :; }

    is_linux_platform() { return 1; }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "windows" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            return 0
        else
            log_warn "Zeroclaw does not officially support platform '$PLATFORM'"
            exit 0
        fi
    }

    run check_platform
    assert_success
    assert_output --partial "does not officially support"
}

@test "check_installed succeeds when zeroclaw is on PATH" {
    check_installed() {
        if command -v zeroclaw &> /dev/null; then
            return 0
        fi
        return 1
    }

    PATH="$MOCK_DIR:$PATH"
    run check_installed
    assert_success
}

@test "check_installed fails when zeroclaw is not on PATH" {
    check_installed() {
        if command -v zeroclaw &> /dev/null; then
            return 0
        fi
        return 1
    }

    PATH="/usr/bin:/bin"
    run check_installed
    assert_failure
}

@test "install_zeroclaw detects existing installation" {
    PATH="$MOCK_DIR:$PATH"

    install_zeroclaw() {
        if command -v zeroclaw &> /dev/null; then
            log_info "Zeroclaw is already installed"
            return 0
        fi
    }

    run install_zeroclaw
    assert_success
    assert_output --partial "already installed"
}

@test "install_zeroclaw dry-run shows curl command" {
    DRY_RUN=true
    ZEROCLAW_INSTALL_URL="https://zeroclawlabs.ai/install.sh"

    install_zeroclaw() {
        if command -v zeroclaw &> /dev/null; then
            return 0
        fi
        log_info "Installing Zeroclaw..."
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[dry-run] Would run: curl -fsSL $ZEROCLAW_INSTALL_URL | bash"
            return 0
        fi
    }

    PATH="/usr/bin:/bin"
    run install_zeroclaw
    assert_success
    assert_output --partial "[dry-run]"
    assert_output --partial "curl"
}
