#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "check-health.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/check-health.sh" ]
}

@test "health check runs for minimal profile" {
    run bash "$REPO_ROOT/scripts/check-health.sh" --profile minimal
    assert_output --partial "Health Check"
}

@test "setup.sh --check --profile minimal works" {
    cd "$REPO_ROOT"
    run bash ./setup.sh --check --profile minimal
    assert_output --partial "Health Check"
}
