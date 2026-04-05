#!/usr/bin/env bats

setup() {
    load '../test_helper'

    TEST_TMPDIR="$(mktemp -d)"
    export HOME="$TEST_TMPDIR/home"
    mkdir -p "$HOME"

    # Create a fake SCRIPT_DIR layout so sourced files resolve
    FAKE_SCRIPT_DIR="$TEST_TMPDIR/scripts"
    mkdir -p "$FAKE_SCRIPT_DIR/lib"
    mkdir -p "$TEST_TMPDIR/backup"

    # Copy real scripts into the fake tree
    cp "$REPO_ROOT/scripts/lib/common.sh" "$FAKE_SCRIPT_DIR/lib/common.sh"
    cp "$REPO_ROOT/scripts/platform-detect.sh" "$FAKE_SCRIPT_DIR/platform-detect.sh"
    cp "$REPO_ROOT/scripts/ini-parser.sh" "$FAKE_SCRIPT_DIR/ini-parser.sh"

    # Build a sourceable version of setup-backup.sh that does NOT run main()
    # We strip the final `main "$@"` call so we can test individual functions.
    sed '
        /^set -euo pipefail$/d
        /^main "\$@"$/d
    ' "$REPO_ROOT/scripts/setup-backup.sh" > "$FAKE_SCRIPT_DIR/setup-backup-functions.sh"

    # Replace SCRIPT_DIR so paths resolve inside the temp tree
    sed -i.bak "s|SCRIPT_DIR=.*|SCRIPT_DIR=\"$FAKE_SCRIPT_DIR\"|" \
        "$FAKE_SCRIPT_DIR/setup-backup-functions.sh"
    rm -f "$FAKE_SCRIPT_DIR/setup-backup-functions.sh.bak"

    # Provide a mock PATH directory for fake commands
    MOCK_BIN="$TEST_TMPDIR/mock-bin"
    mkdir -p "$MOCK_BIN"

    # Default: put a fake restic on PATH
    printf '#!/usr/bin/env bash\nexit 0\n' > "$MOCK_BIN/restic"
    chmod +x "$MOCK_BIN/restic"

    export PATH="$MOCK_BIN:$PATH"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# Helper to source the functions file
source_setup_backup() {
    # Unset the guard so common.sh can be re-sourced
    unset _COMMON_SH_LOADED
    source "$FAKE_SCRIPT_DIR/setup-backup-functions.sh"
}

# -------------------------------------------------------------------
# 1. check_restic_installed fails when restic not on PATH
# -------------------------------------------------------------------
@test "check_restic_installed fails when restic is not on PATH" {
    rm -f "$MOCK_BIN/restic"
    # Restrict PATH to only our mock bin (no system restic)
    source_setup_backup
    PATH="$MOCK_BIN" run check_restic_installed
    assert_failure
    assert_output --partial "Restic is not installed"
}

@test "check_restic_installed succeeds when restic is on PATH" {
    source_setup_backup
    run check_restic_installed
    assert_success
}

# -------------------------------------------------------------------
# 2. create_config_template creates the config file
# -------------------------------------------------------------------
@test "create_config_template creates config file" {
    source_setup_backup
    # CONFIG_FILE points into the fake tree
    [[ ! -f "$CONFIG_FILE" ]]
    run create_config_template
    assert_success
    assert [ -f "$CONFIG_FILE" ]
}

# -------------------------------------------------------------------
# 3. create_config_template skips if config already exists
# -------------------------------------------------------------------
@test "create_config_template skips when config already exists" {
    source_setup_backup
    echo "existing" > "$CONFIG_FILE"
    run create_config_template
    assert_success
    assert_output --partial "already exists"
    # File should be untouched
    run cat "$CONFIG_FILE"
    assert_output "existing"
}

# -------------------------------------------------------------------
# 4. Config template has all required INI sections
# -------------------------------------------------------------------
@test "config template contains all required INI sections" {
    source_setup_backup
    create_config_template

    for section in repository retention paths excludes b2 s3; do
        run grep "^\[${section}\]" "$CONFIG_FILE"
        assert_success
    done
}

# -------------------------------------------------------------------
# 5. setup_systemd_timer creates service and timer files
# -------------------------------------------------------------------
@test "setup_systemd_timer creates service and timer files on supported platform" {
    # Mock systemctl
    printf '#!/usr/bin/env bash\nexit 0\n' > "$MOCK_BIN/systemctl"
    chmod +x "$MOCK_BIN/systemctl"

    source_setup_backup
    # Override detect_platform so it doesn't reset our PLATFORM value
    detect_platform() { :; }
    PLATFORM="ubuntu"

    run setup_systemd_timer
    assert_success

    local service_file="$HOME/.config/systemd/user/restic-backup.service"
    local timer_file="$HOME/.config/systemd/user/restic-backup.timer"

    assert [ -f "$service_file" ]
    assert [ -f "$timer_file" ]

    # Verify service file content
    run grep "ExecStart=" "$service_file"
    assert_success

    # Verify timer file content
    run grep "OnCalendar=daily" "$timer_file"
    assert_success
}

@test "setup_systemd_timer skips on unsupported platform" {
    printf '#!/usr/bin/env bash\nexit 0\n' > "$MOCK_BIN/systemctl"
    chmod +x "$MOCK_BIN/systemctl"

    source_setup_backup
    detect_platform() { :; }
    PLATFORM="macos"

    run setup_systemd_timer
    assert_success
    assert_output --partial "not available"
}

# -------------------------------------------------------------------
# 6. setup_launchd_plist handles missing plist template gracefully
# -------------------------------------------------------------------
@test "setup_launchd_plist warns and falls back when plist template missing" {
    source_setup_backup
    # The plist template won't exist in our fake tree, so it should warn
    # and fall back to setup_cron_job
    PLATFORM="macos"

    run setup_launchd_plist
    assert_success
    assert_output --partial "plist template not found"
}

@test "setup_launchd_plist installs plist when template exists" {
    # Mock launchctl
    printf '#!/usr/bin/env bash\nexit 0\n' > "$MOCK_BIN/launchctl"
    chmod +x "$MOCK_BIN/launchctl"

    # Create a fake plist template
    local plist_src="$FAKE_SCRIPT_DIR/../backup/com.user.restic-backup.plist"
    mkdir -p "$(dirname "$plist_src")"
    echo "<plist>test</plist>" > "$plist_src"

    source_setup_backup
    mkdir -p "$HOME/Library/LaunchAgents"

    run setup_launchd_plist
    assert_success
    assert_output --partial "plist installed"
    assert [ -f "$HOME/Library/LaunchAgents/com.user.restic-backup.plist" ]
}

# -------------------------------------------------------------------
# 7. setup_cron_job outputs cron line
# -------------------------------------------------------------------
@test "setup_cron_job outputs cron line on non-macos platform" {
    source_setup_backup
    detect_platform() { :; }
    PLATFORM="ubuntu"

    run setup_cron_job
    assert_success
    assert_output --partial "0 2 * * *"
    assert_output --partial "backup.sh"
}

@test "setup_cron_job suggests launchd on macos" {
    source_setup_backup
    detect_platform() { :; }
    PLATFORM="macos"

    run setup_cron_job
    assert_success
    assert_output --partial "launchd"
}
