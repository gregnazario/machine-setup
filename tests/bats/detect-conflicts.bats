#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "detect-conflicts.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/detect-conflicts.sh" ]
}

@test "detect-conflicts.sh runs for minimal profile" {
    run bash "$REPO_ROOT/scripts/detect-conflicts.sh" --profile minimal
    assert_output --partial "Dotfile Conflict Detection"
}

@test "detect-conflicts.sh reports no conflicts on clean repo" {
    run bash "$REPO_ROOT/scripts/detect-conflicts.sh" --profile minimal
    assert_output --partial "No Syncthing conflicts found"
}
