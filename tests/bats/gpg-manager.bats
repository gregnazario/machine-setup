#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "gpg-manager.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/gpg-manager.sh" ]
}

@test "gpg-manager.sh without args shows usage" {
    run bash "$REPO_ROOT/scripts/gpg-manager.sh"
    assert_failure
    assert_output --partial "Usage"
}

@test "gpg status runs without error" {
    if ! command -v gpg &>/dev/null; then
        skip "gpg not installed"
    fi
    run bash "$REPO_ROOT/scripts/gpg-manager.sh" status
    assert_success
    assert_output --partial "GPG Key Status"
}

@test "setup.sh --help mentions --gpg" {
    cd "$REPO_ROOT"
    run bash setup.sh --help
    assert_output --partial "--gpg"
}
