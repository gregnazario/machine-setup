#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "remote-setup.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/remote-setup.sh" ]
}

@test "remote-setup.sh without args shows usage" {
    run bash "$REPO_ROOT/scripts/remote-setup.sh"
    assert_failure
    assert_output --partial "Usage"
}

@test "setup.sh --help mentions --remote" {
    cd "$REPO_ROOT"
    run bash setup.sh --help
    assert_output --partial "--remote"
}
