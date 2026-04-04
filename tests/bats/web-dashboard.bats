#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "web-dashboard.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/web-dashboard.sh" ]
}

@test "setup.sh --help mentions --serve" {
    cd "$REPO_ROOT"
    run bash setup.sh --help
    assert_output --partial "--serve"
}
