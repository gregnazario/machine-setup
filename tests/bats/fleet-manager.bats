#!/usr/bin/env bats

setup() {
    load '../test_helper'
    TEST_DIR="$(mktemp -d)"
    export MACHINE_SETUP_DIR="$TEST_DIR"
    export REPO_DIR="$REPO_ROOT"
    source "$REPO_ROOT/scripts/fleet-manager.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "fleet-manager.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/fleet-manager.sh" ]
}

@test "fleet register adds a machine" {
    fleet_register "testbox" "user@testbox.local" "minimal"
    run grep "machine.testbox" "$FLEET_FILE"
    assert_success
}

@test "fleet list shows registered machines" {
    fleet_register "box1" "user@box1" "full"
    run fleet_list
    assert_output --partial "box1"
    assert_output --partial "user@box1"
}

@test "fleet remove deletes a machine" {
    fleet_register "deleteme" "user@deleteme" "full"
    fleet_remove "deleteme"
    run grep "machine.deleteme" "$FLEET_FILE"
    assert_failure
}

@test "fleet list with no machines shows info" {
    run fleet_list
    assert_output --partial "No machines registered"
}

@test "setup.sh --help mentions --fleet" {
    cd "$REPO_ROOT"
    run bash setup.sh --help
    assert_output --partial "--fleet"
}
