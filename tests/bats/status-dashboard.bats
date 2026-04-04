#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "status-dashboard.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/status-dashboard.sh" ]
}

@test "status dashboard runs for minimal profile" {
    cd "$REPO_ROOT"
    run bash scripts/status-dashboard.sh --profile minimal
    assert_success
    assert_output --partial "Status Dashboard"
}

@test "status dashboard shows platform info" {
    cd "$REPO_ROOT"
    run bash scripts/status-dashboard.sh --profile minimal
    assert_success
    assert_output --partial "Platform"
    assert_output --partial "Package Manager"
}

@test "status dashboard shows key packages" {
    cd "$REPO_ROOT"
    run bash scripts/status-dashboard.sh --profile minimal
    assert_success
    assert_output --partial "Key Packages"
    assert_output --partial "git"
}

@test "setup.sh --help mentions --status" {
    cd "$REPO_ROOT"
    run bash setup.sh --help
    assert_output --partial "--status"
}
