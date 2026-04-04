#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "validate-profile.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/validate-profile.sh" ]
}

@test "minimal profile validates successfully" {
    run bash "$REPO_ROOT/scripts/validate-profile.sh" --profile minimal
    assert_success
    assert_output --partial "is valid"
}

@test "full profile validates successfully" {
    run bash "$REPO_ROOT/scripts/validate-profile.sh" --profile full
    assert_success
    assert_output --partial "is valid"
}

@test "selfhosted profile validates successfully" {
    run bash "$REPO_ROOT/scripts/validate-profile.sh" --profile selfhosted
    assert_success
    assert_output --partial "is valid"
}

@test "nonexistent profile fails" {
    run bash "$REPO_ROOT/scripts/validate-profile.sh" --profile nonexistent_profile_xyz
    assert_failure
}

@test "setup.sh --validate-profile minimal works" {
    cd "$REPO_ROOT"
    run bash ./setup.sh --validate-profile minimal
    assert_success
    assert_output --partial "is valid"
}
