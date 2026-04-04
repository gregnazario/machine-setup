#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "build-image.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/build-image.sh" ]
}

@test "build-image.sh without args shows usage" {
    run bash "$REPO_ROOT/scripts/build-image.sh"
    assert_failure
    assert_output --partial "Usage"
}

@test "build-image.sh --dry-run generates Dockerfile" {
    if ! command -v docker &>/dev/null; then
        skip "docker not installed"
    fi
    cd "$REPO_ROOT"
    run bash scripts/build-image.sh minimal --dry-run
    assert_success
    assert_output --partial "FROM"
    assert_output --partial "setup.sh"
}

@test "setup.sh --help mentions --build-image" {
    cd "$REPO_ROOT"
    run bash setup.sh --help
    assert_output --partial "build-image"
}
