#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "bash completion file exists" {
    assert [ -f "$REPO_ROOT/completions/setup.bash" ]
}

@test "zsh completion file exists" {
    assert [ -f "$REPO_ROOT/completions/setup.zsh" ]
}

@test "fish completion file exists" {
    assert [ -f "$REPO_ROOT/completions/setup.fish" ]
}

@test "bash completion contains all major flags" {
    run grep -c '\-\-' "$REPO_ROOT/completions/setup.bash"
    # Should have multiple flag references
    [ "$output" -gt 2 ]
}

@test "completions reference profile discovery" {
    run grep "profiles" "$REPO_ROOT/completions/setup.bash"
    assert_success
    run grep "profiles" "$REPO_ROOT/completions/setup.zsh"
    assert_success
    run grep "profiles" "$REPO_ROOT/completions/setup.fish"
    assert_success
}
