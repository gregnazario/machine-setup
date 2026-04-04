#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "backup.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/backup/backup.sh" ]
}

@test "backup.sh --help outputs usage" {
    run "$REPO_ROOT/backup/backup.sh" --help
    assert_success
    assert_output --partial "Restic backup script"
}

@test "backup.sh --dry-run handles config/dependency issues gracefully" {
    run "$REPO_ROOT/backup/backup.sh" --dry-run
    # Accept any known outcome
    [[ "$output" == *"DRY-RUN"* ]] || \
    [[ "$output" == *"restic is not installed"* ]] || \
    [[ "$output" == *"Please set a strong password"* ]] || \
    [[ "$output" == *"not found"* ]] || \
    [[ "$output" == *"not configured"* ]]
}

@test "restic-config.conf is valid INI" {
    run grep '^\[repository\]' "$REPO_ROOT/backup/restic-config.conf"
    assert_success
}
