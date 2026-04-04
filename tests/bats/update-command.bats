#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "setup.sh --help mentions --update" {
    cd "$REPO_ROOT"
    run bash setup.sh --help
    assert_output --partial "--update"
}

@test "setup.sh --update is handled in parse_args" {
    run grep -c '\-\-update)' "$REPO_ROOT/setup.sh"
    assert_output "1"
}
