#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "verify-backup.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/verify-backup.sh" ]
}

@test "verify-backup.sh handles missing config gracefully" {
    run bash "$REPO_ROOT/scripts/verify-backup.sh"
    # Should report placeholder credentials or missing restic
    [[ "$output" == *"not configured"* ]] || \
    [[ "$output" == *"placeholder"* ]] || \
    [[ "$output" == *"not installed"* ]] || \
    [[ "$output" == *"not found"* ]]
}

@test "setup.sh --help mentions verify-backup" {
    run bash "$REPO_ROOT/setup.sh" --help
    assert_output --partial "verify-backup"
}

@test "setup.sh --help mentions detect-conflicts" {
    run bash "$REPO_ROOT/setup.sh" --help
    assert_output --partial "detect-conflicts"
}
