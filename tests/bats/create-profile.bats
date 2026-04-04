#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

teardown() {
    rm -f "$REPO_ROOT/profiles/testprofile.conf"
    rm -f "$REPO_ROOT/profiles/testprofile2.conf"
}

@test "setup.sh --create-profile creates a new profile file" {
    cd "$REPO_ROOT"
    run bash setup.sh --create-profile testprofile
    assert_success
    assert [ -f "$REPO_ROOT/profiles/testprofile.conf" ]
}

@test "created profile has required sections" {
    cd "$REPO_ROOT"
    bash setup.sh --create-profile testprofile2
    run grep '^\[profile\]' "$REPO_ROOT/profiles/testprofile2.conf"
    assert_success
    run grep '^\[packages\]' "$REPO_ROOT/profiles/testprofile2.conf"
    assert_success
}

@test "create-profile refuses to overwrite existing profile" {
    cd "$REPO_ROOT"
    run bash setup.sh --create-profile minimal
    assert_failure
    assert_output --partial "already exists"
}
