#!/usr/bin/env bats

setup() {
    load '../test_helper'
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"

    # Create a fake dotfiles source directory
    DOTFILES_DIR="$TEST_HOME/dotfiles"
    mkdir -p "$DOTFILES_DIR"

    source "$REPO_ROOT/scripts/lib/common.sh"

    # Source unlink-dotfiles.sh functions (guarded by BASH_SOURCE check)
    DRY_RUN=false
    source "$REPO_ROOT/scripts/unlink-dotfiles.sh"
}

teardown() {
    rm -rf "$TEST_HOME"
}

@test "remove_symlink removes symlink pointing into dotfiles dir" {
    # Create a file in dotfiles dir and symlink to it
    echo "content" > "$DOTFILES_DIR/testfile"
    ln -s "$DOTFILES_DIR/testfile" "$TEST_HOME/link"

    remove_symlink "$TEST_HOME/link" "$DOTFILES_DIR"

    assert [ ! -L "$TEST_HOME/link" ]
}

@test "remove_symlink skips symlink not pointing into dotfiles dir" {
    # Create a file outside the dotfiles dir
    mkdir -p "$TEST_HOME/other"
    echo "content" > "$TEST_HOME/other/testfile"
    ln -s "$TEST_HOME/other/testfile" "$TEST_HOME/link"

    run remove_symlink "$TEST_HOME/link" "$DOTFILES_DIR"

    assert_output --partial "Skipping (not managed)"
    assert [ -L "$TEST_HOME/link" ]
}

@test "remove_symlink does nothing for non-symlink targets" {
    echo "regular file" > "$TEST_HOME/regular"

    run remove_symlink "$TEST_HOME/regular" "$DOTFILES_DIR"

    assert_success
    assert [ -f "$TEST_HOME/regular" ]
}

@test "remove_symlink does nothing for nonexistent targets" {
    run remove_symlink "$TEST_HOME/nonexistent" "$DOTFILES_DIR"

    assert_success
}

@test "dry-run mode prints message but does not remove symlink" {
    echo "content" > "$DOTFILES_DIR/testfile"
    ln -s "$DOTFILES_DIR/testfile" "$TEST_HOME/link"

    DRY_RUN=true
    run remove_symlink "$TEST_HOME/link" "$DOTFILES_DIR"

    assert_output --partial "Would remove symlink"
    assert [ -L "$TEST_HOME/link" ]
}
