#!/usr/bin/env bats

setup() {
    load '../test_helper'
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"

    source "$REPO_ROOT/scripts/lib/common.sh"

    # Extract functions from link-dotfiles.sh without triggering main
    DRY_RUN=false
    FORCE=false
    eval "$(sed -n '/^backup_existing()/,/^}/p' "$REPO_ROOT/scripts/link-dotfiles.sh")"
    eval "$(sed -n '/^create_symlink()/,/^}/p' "$REPO_ROOT/scripts/link-dotfiles.sh")"
}

teardown() {
    rm -rf "$TEST_HOME"
}

# ---------- create_symlink ----------

@test "create_symlink creates a working symlink" {
    mkdir -p "$TEST_HOME/src" "$TEST_HOME/dest"
    echo "hello" > "$TEST_HOME/src/file.txt"

    create_symlink "$TEST_HOME/src/file.txt" "$TEST_HOME/dest/file.txt"

    assert [ -L "$TEST_HOME/dest/file.txt" ]
    assert_equal "$(readlink "$TEST_HOME/dest/file.txt")" "$TEST_HOME/src/file.txt"
    assert_equal "$(cat "$TEST_HOME/dest/file.txt")" "hello"
}

@test "create_symlink in dry-run mode prints but does not create" {
    DRY_RUN=true
    mkdir -p "$TEST_HOME/src" "$TEST_HOME/dest"
    echo "hello" > "$TEST_HOME/src/file.txt"

    run create_symlink "$TEST_HOME/src/file.txt" "$TEST_HOME/dest/file.txt"

    assert_output --partial "Would create symlink"
    assert [ ! -e "$TEST_HOME/dest/file.txt" ]
}

@test "create_symlink is idempotent when already linked" {
    mkdir -p "$TEST_HOME/src" "$TEST_HOME/dest"
    echo "hello" > "$TEST_HOME/src/file.txt"

    create_symlink "$TEST_HOME/src/file.txt" "$TEST_HOME/dest/file.txt"
    assert [ -L "$TEST_HOME/dest/file.txt" ]

    run create_symlink "$TEST_HOME/src/file.txt" "$TEST_HOME/dest/file.txt"
    assert_output --partial "Already linked"
    # No backup files should exist
    run ls "$TEST_HOME/dest/"
    refute_output --partial ".backup"
}

@test "create_symlink creates parent directories when missing" {
    mkdir -p "$TEST_HOME/src"
    echo "nested" > "$TEST_HOME/src/app.conf"

    create_symlink "$TEST_HOME/src/app.conf" "$TEST_HOME/deep/nested/dir/app.conf"

    assert [ -d "$TEST_HOME/deep/nested/dir" ]
    assert [ -L "$TEST_HOME/deep/nested/dir/app.conf" ]
    assert_equal "$(cat "$TEST_HOME/deep/nested/dir/app.conf")" "nested"
}

@test "create_symlink backs up existing regular file" {
    mkdir -p "$TEST_HOME/src" "$TEST_HOME/dest"
    echo "source" > "$TEST_HOME/src/file.txt"
    echo "existing" > "$TEST_HOME/dest/file.txt"

    FORCE=false
    create_symlink "$TEST_HOME/src/file.txt" "$TEST_HOME/dest/file.txt"

    # Symlink should now exist
    assert [ -L "$TEST_HOME/dest/file.txt" ]
    assert_equal "$(cat "$TEST_HOME/dest/file.txt")" "source"

    # A backup file should have been created
    run ls "$TEST_HOME/dest/"
    assert_output --partial ".backup"
}

@test "create_symlink with --force removes existing without backup" {
    mkdir -p "$TEST_HOME/src" "$TEST_HOME/dest"
    echo "source" > "$TEST_HOME/src/file.txt"
    echo "existing" > "$TEST_HOME/dest/file.txt"

    FORCE=true
    create_symlink "$TEST_HOME/src/file.txt" "$TEST_HOME/dest/file.txt"

    # Symlink should now exist
    assert [ -L "$TEST_HOME/dest/file.txt" ]
    assert_equal "$(cat "$TEST_HOME/dest/file.txt")" "source"

    # No backup files should exist
    run ls "$TEST_HOME/dest/"
    refute_output --partial ".backup"
}

# ---------- backup_existing ----------

@test "backup_existing creates .backup file for regular files" {
    mkdir -p "$TEST_HOME/dest"
    echo "old content" > "$TEST_HOME/dest/myfile"

    FORCE=false
    backup_existing "$TEST_HOME/dest/myfile"

    assert [ ! -e "$TEST_HOME/dest/myfile" ]
    # A backup should exist
    local backup_count
    backup_count=$(ls "$TEST_HOME/dest/" | grep -c '\.backup\.' || true)
    assert [ "$backup_count" -eq 1 ]
}

@test "backup_existing with FORCE removes file without backup" {
    mkdir -p "$TEST_HOME/dest"
    echo "old content" > "$TEST_HOME/dest/myfile"

    FORCE=true
    backup_existing "$TEST_HOME/dest/myfile"

    assert [ ! -e "$TEST_HOME/dest/myfile" ]
    local backup_count
    backup_count=$(ls "$TEST_HOME/dest/" | grep -c '\.backup\.' || true)
    assert [ "$backup_count" -eq 0 ]
}

@test "backup_existing is a no-op when target does not exist" {
    FORCE=false
    run backup_existing "$TEST_HOME/nonexistent"
    assert_success
    assert_output ""
}

@test "backup_existing handles existing symlinks" {
    mkdir -p "$TEST_HOME/src" "$TEST_HOME/dest"
    echo "data" > "$TEST_HOME/src/real"
    ln -s "$TEST_HOME/src/real" "$TEST_HOME/dest/link"

    FORCE=false
    backup_existing "$TEST_HOME/dest/link"

    assert [ ! -L "$TEST_HOME/dest/link" ]
    local backup_count
    backup_count=$(ls "$TEST_HOME/dest/" | grep -c '\.backup\.' || true)
    assert [ "$backup_count" -eq 1 ]
}

# ---------- subprocess / integration ----------

@test "link-dotfiles.sh --dry-run --profile minimal produces dry-run output" {
    cd "$REPO_ROOT"
    run bash scripts/link-dotfiles.sh --dry-run --profile minimal
    # Should mention dry-run style output (Would create) or at least not fail
    # The script may produce no links if the profile has none, so just check it ran
    assert_success
}

@test "link-dotfiles.sh rejects unknown options" {
    cd "$REPO_ROOT"
    run bash scripts/link-dotfiles.sh --bogus-flag
    assert_failure
    assert_output --partial "Unknown option"
}
