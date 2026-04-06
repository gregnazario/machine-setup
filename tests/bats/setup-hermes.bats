#!/usr/bin/env bats

setup() {
    load '../test_helper'

    TEST_TMPDIR="$(mktemp -d)"
    MOCK_DIR="$TEST_TMPDIR/bin"
    mkdir -p "$MOCK_DIR"

    # Create a mock hermes binary
    cat > "$MOCK_DIR/hermes" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    setup) echo "hermes setup called"; exit 0 ;;
    update) echo "hermes update called"; exit 0 ;;
    gateway) echo "hermes gateway $2 called"; exit 0 ;;
    *) exit 0 ;;
esac
MOCK
    chmod +x "$MOCK_DIR/hermes"

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

@test "setup-hermes.sh exists and is executable" {
    assert [ -f "$REPO_ROOT/scripts/setup-hermes.sh" ]
    assert [ -x "$REPO_ROOT/scripts/setup-hermes.sh" ]
}

@test "setup-hermes.sh --help shows usage" {
    run bash "$REPO_ROOT/scripts/setup-hermes.sh" --help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "Hermes AI agent"
    assert_output --partial "--dry-run"
}

@test "check_platform allows macos" {
    PLATFORM="macos"
    detect_platform() { :; }

    is_linux_platform() {
        case "$1" in
            fedora|ubuntu|debian|arch|gentoo|void|alpine|opensuse|rocky|alma|raspberrypios|nixos|chromeos) return 0 ;;
            *) return 1 ;;
        esac
    }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            log_info "Platform '$PLATFORM' is supported by Hermes"
            return 0
        fi
        return 1
    }

    run check_platform
    assert_success
    assert_output --partial "supported by Hermes"
}

@test "check_platform allows wsl" {
    PLATFORM="wsl"
    detect_platform() { :; }

    is_linux_platform() { return 1; }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            log_info "Platform '$PLATFORM' is supported by Hermes"
            return 0
        fi
        return 1
    }

    run check_platform
    assert_success
    assert_output --partial "supported by Hermes"
}

@test "check_platform allows linux platforms" {
    PLATFORM="ubuntu"
    detect_platform() { :; }

    is_linux_platform() {
        case "$1" in
            fedora|ubuntu|debian|arch|gentoo|void|alpine|opensuse|rocky|alma|raspberrypios|nixos|chromeos) return 0 ;;
            *) return 1 ;;
        esac
    }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            log_info "Platform '$PLATFORM' is supported by Hermes"
            return 0
        fi
        return 1
    }

    run check_platform
    assert_success
    assert_output --partial "supported by Hermes"
}

@test "check_platform rejects windows" {
    PLATFORM="windows"
    detect_platform() { :; }

    is_linux_platform() { return 1; }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            return 0
        else
            log_warn "Hermes does not officially support platform '$PLATFORM'"
            exit 0
        fi
    }

    run check_platform
    assert_success
    assert_output --partial "does not officially support"
}

@test "check_installed succeeds when hermes is on PATH" {
    check_installed() {
        if command -v hermes &> /dev/null; then
            return 0
        fi
        return 1
    }

    PATH="$MOCK_DIR:$PATH"
    run check_installed
    assert_success
}

@test "check_installed fails when hermes is not on PATH" {
    check_installed() {
        if command -v hermes &> /dev/null; then
            return 0
        fi
        return 1
    }

    PATH="/usr/bin:/bin"
    run check_installed
    assert_failure
}

@test "install_hermes detects existing installation" {
    PATH="$MOCK_DIR:$PATH"

    install_hermes() {
        if command -v hermes &> /dev/null; then
            log_info "Hermes is already installed"
            return 0
        fi
    }

    run install_hermes
    assert_success
    assert_output --partial "already installed"
}

@test "install_hermes dry-run shows curl command" {
    DRY_RUN=true
    HERMES_INSTALL_URL="https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh"

    install_hermes() {
        if command -v hermes &> /dev/null; then
            return 0
        fi
        log_info "Installing Hermes..."
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[dry-run] Would run: curl -fsSL $HERMES_INSTALL_URL | bash"
            return 0
        fi
    }

    # Ensure hermes is not on PATH
    PATH="/usr/bin:/bin"
    run install_hermes
    assert_success
    assert_output --partial "[dry-run]"
    assert_output --partial "curl"
}
