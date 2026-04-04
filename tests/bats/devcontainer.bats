#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "devcontainer.json exists" {
    assert [ -f "$REPO_ROOT/.devcontainer/devcontainer.json" ]
}

@test "devcontainer.json is valid JSON" {
    if command -v python3 &>/dev/null; then
        run python3 -c "import json; json.load(open('$REPO_ROOT/.devcontainer/devcontainer.json'))"
        assert_success
    else
        skip "python3 not available"
    fi
}

@test "Dockerfile exists" {
    assert [ -f "$REPO_ROOT/.devcontainer/Dockerfile" ]
}

@test "Dockerfile references setup.sh" {
    run grep "setup.sh" "$REPO_ROOT/.devcontainer/Dockerfile"
    assert_success
}
