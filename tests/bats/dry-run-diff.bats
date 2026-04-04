#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "dry-run-diff.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/dry-run-diff.sh" ]
}

@test "dry-run-diff outputs legend" {
    cd "$REPO_ROOT"
    run bash scripts/dry-run-diff.sh --profile minimal
    assert_success
    assert_output --partial "Legend"
}

@test "dry-run-diff shows package status" {
    cd "$REPO_ROOT"
    run bash scripts/dry-run-diff.sh --profile minimal
    assert_success
    assert_output --partial "git"
}
