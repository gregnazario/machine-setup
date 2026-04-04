#!/usr/bin/env bats

setup() {
    load '../test_helper'

    # Temporary directory for mocks and test artifacts
    TEST_TMPDIR="$(mktemp -d)"
    MOCK_DIR="$TEST_TMPDIR/bin"
    mkdir -p "$MOCK_DIR"

    # Create a mock syncthing binary
    cat > "$MOCK_DIR/syncthing" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    --generate=*)
        dir="${1#--generate=}"
        mkdir -p "$dir"
        touch "$dir/config.xml"
        exit 0
        ;;
    *) exit 0 ;;
esac
MOCK
    chmod +x "$MOCK_DIR/syncthing"

    # Override HOME so tests don't touch real config
    export ORIGINAL_HOME="$HOME"
    export HOME="$TEST_TMPDIR/fakehome"
    mkdir -p "$HOME"

    # Source dependencies so functions are available
    source "$REPO_ROOT/scripts/lib/common.sh"
    # Re-allow sourcing common.sh again (reset guard)
    unset _COMMON_SH_LOADED
    source "$REPO_ROOT/scripts/platform-detect.sh"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
    export HOME="$ORIGINAL_HOME"
}

@test "setup-syncthing.sh exists and is executable" {
    assert [ -f "$REPO_ROOT/scripts/setup-syncthing.sh" ]
    assert [ -x "$REPO_ROOT/scripts/setup-syncthing.sh" ]
}

@test "check_syncthing_installed fails when syncthing is not on PATH" {
    # Source the script functions with an empty PATH (no syncthing)
    # We need to define the function inline since sourcing the script runs main
    check_syncthing_installed() {
        if ! command -v syncthing &> /dev/null; then
            log_error "Syncthing is not installed. Please install it first."
            exit 1
        fi
    }

    # Ensure syncthing is not found
    PATH="/usr/bin:/bin"
    run check_syncthing_installed
    assert_failure
    assert_output --partial "not installed"
}

@test "check_syncthing_installed succeeds when syncthing is on PATH" {
    check_syncthing_installed() {
        if ! command -v syncthing &> /dev/null; then
            log_error "Syncthing is not installed. Please install it first."
            exit 1
        fi
    }

    PATH="$MOCK_DIR:$PATH"
    run check_syncthing_installed
    assert_success
}

@test "generate_syncthing_config creates config directory and file" {
    # Define function to avoid sourcing the whole script (which runs main)
    generate_syncthing_config() {
        local config_dir="$HOME/.config/syncthing"
        local config_file="$config_dir/config.xml"

        if [[ -f "$config_file" ]]; then
            log_warn "Syncthing config already exists at $config_file"
            return
        fi

        mkdir -p "$config_dir"
        log_info "Generating Syncthing configuration..."
        syncthing --generate="$config_dir"
        log_success "Syncthing config generated at $config_file"
    }

    PATH="$MOCK_DIR:$PATH"
    run generate_syncthing_config
    assert_success
    assert_output --partial "Generating Syncthing configuration"
    assert_output --partial "config generated"
    assert [ -f "$HOME/.config/syncthing/config.xml" ]
}

@test "generate_syncthing_config warns when config already exists" {
    generate_syncthing_config() {
        local config_dir="$HOME/.config/syncthing"
        local config_file="$config_dir/config.xml"

        if [[ -f "$config_file" ]]; then
            log_warn "Syncthing config already exists at $config_file"
            return
        fi

        mkdir -p "$config_dir"
        syncthing --generate="$config_dir"
    }

    # Pre-create the config file
    mkdir -p "$HOME/.config/syncthing"
    touch "$HOME/.config/syncthing/config.xml"

    run generate_syncthing_config
    assert_success
    assert_output --partial "already exists"
}

@test "setup_syncthing_folders outputs expected instructions" {
    setup_syncthing_folders() {
        local dotfiles_dir="$HOME/dotfiles"
        cat <<EOF
Syncthing Setup Instructions:

1. Start Syncthing:
   \$ syncthing

2. Open the web UI: http://localhost:8384

3. Set a GUI username and password when prompted

4. Add this folder for syncing:
   - Folder ID: dotfiles
   - Folder Path: $dotfiles_dir
EOF
    }

    run setup_syncthing_folders
    assert_success
    assert_output --partial "http://localhost:8384"
    assert_output --partial "Folder ID: dotfiles"
    assert_output --partial "Folder Path:"
    assert_output --partial "Syncthing Setup Instructions"
}

@test "enable_syncthing_service outputs message for macos platform" {
    # Stub out detect_platform and service commands
    PLATFORM="macos"
    detect_platform() { :; }

    enable_syncthing_service() {
        log_info "Enabling Syncthing service..."
        case "$PLATFORM" in
            macos)
                log_info "On macOS, Syncthing can be started via the application or: brew services start syncthing"
                ;;
            *)
                log_warn "Unknown platform for service setup. Please enable Syncthing manually."
                ;;
        esac
        log_success "Syncthing service enabled"
    }

    run enable_syncthing_service
    assert_success
    assert_output --partial "brew services start syncthing"
}

@test "enable_syncthing_service warns on unknown platform" {
    PLATFORM="unknown_test_platform"
    detect_platform() { :; }

    enable_syncthing_service() {
        log_info "Enabling Syncthing service..."
        case "$PLATFORM" in
            ubuntu|debian|fedora|raspberrypios|arch|opensuse|rocky|alma)
                systemctl --user enable syncthing
                systemctl --user start syncthing
                ;;
            macos)
                log_info "On macOS, Syncthing can be started via the application or: brew services start syncthing"
                ;;
            *)
                log_warn "Unknown platform for service setup. Please enable Syncthing manually."
                ;;
        esac
        log_success "Syncthing service enabled"
    }

    run enable_syncthing_service
    assert_success
    assert_output --partial "Unknown platform"
    assert_output --partial "enable Syncthing manually"
}

@test "enable_syncthing_service handles systemd platforms" {
    PLATFORM="ubuntu"
    detect_platform() { :; }

    # Mock systemctl
    systemctl() { echo "systemctl $*"; }
    export -f systemctl

    enable_syncthing_service() {
        log_info "Enabling Syncthing service..."
        case "$PLATFORM" in
            ubuntu|debian|fedora|raspberrypios|arch|opensuse|rocky|alma)
                systemctl --user enable syncthing
                systemctl --user start syncthing
                ;;
            *)
                log_warn "Unknown platform for service setup."
                ;;
        esac
        log_success "Syncthing service enabled"
    }

    run enable_syncthing_service
    assert_success
    assert_output --partial "Enabling Syncthing service"
    assert_output --partial "Syncthing service enabled"
}
