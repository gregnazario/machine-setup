#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "diff-profiles.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/diff-profiles.sh" ]
}

@test "diff minimal vs full shows differences" {
    cd "$REPO_ROOT"
    run bash scripts/diff-profiles.sh minimal full
    assert_success
    assert_output --partial "Profile Diff"
    assert_output --partial "Packages"
}

@test "diff profile with itself shows identical" {
    cd "$REPO_ROOT"
    run bash scripts/diff-profiles.sh minimal minimal
    assert_success
    assert_output --partial "identical"
}

@test "setup.sh --help mentions --diff-profiles" {
    cd "$REPO_ROOT"
    run bash setup.sh --help
    assert_output --partial "diff-profiles"
}
