#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "interactive-setup.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/interactive-setup.sh" ]
}

@test "setup.sh --help mentions --interactive" {
    cd "$REPO_ROOT"
    run bash setup.sh --help
    assert_output --partial "--interactive"
}

@test "interactive-setup.sh sources required libraries" {
    run grep "source.*lib/common.sh" "$REPO_ROOT/scripts/interactive-setup.sh"
    assert_success
    run grep "source.*platform-detect.sh" "$REPO_ROOT/scripts/interactive-setup.sh"
    assert_success
}
