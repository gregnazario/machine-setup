#!/usr/bin/env bats

setup() {
    load '../test_helper'
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"
    source "$REPO_ROOT/scripts/lib/common.sh"
    source "$REPO_ROOT/scripts/platform-detect.sh"
    source "$REPO_ROOT/scripts/ini-parser.sh"
    # Source link-dotfiles.sh functions without running main
    # by defining the functions inline from the script
    DRY_RUN=false
    FORCE=false
    eval "$(sed -n '/^create_symlink()/,/^}/p' "$REPO_ROOT/scripts/link-dotfiles.sh")"
    eval "$(sed -n '/^backup_existing()/,/^}/p' "$REPO_ROOT/scripts/link-dotfiles.sh")"
}

teardown() {
    rm -rf "$TEST_HOME"
}

@test "dry-run output is identical on two consecutive runs" {
    cd "$REPO_ROOT"
    output1="$(bash setup.sh --dry-run --no-syncthing --no-backup --profile minimal 2>&1)" || true
    output2="$(bash setup.sh --dry-run --no-syncthing --no-backup --profile minimal 2>&1)" || true
    assert [ "$output1" = "$output2" ]
}

@test "create_symlink is idempotent" {
    DRY_RUN=false
    FORCE=false
    mkdir -p "$TEST_HOME/src" "$TEST_HOME/dest"
    echo "content" > "$TEST_HOME/src/testfile"

    create_symlink "$TEST_HOME/src/testfile" "$TEST_HOME/dest/testfile"
    assert [ -L "$TEST_HOME/dest/testfile" ]

    run create_symlink "$TEST_HOME/src/testfile" "$TEST_HOME/dest/testfile"
    assert_output --partial "Already linked"
}
