#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "flake.nix exists" {
    assert [ -f "$REPO_ROOT/flake.nix" ]
}

@test "flake.nix contains devShells.default" {
    run grep "devShells.default" "$REPO_ROOT/flake.nix"
    assert_success
}

@test "flake.nix contains devShells.full" {
    run grep "devShells.full" "$REPO_ROOT/flake.nix"
    assert_success
}

@test "flake.nix includes minimal profile packages" {
    run grep "nushell" "$REPO_ROOT/flake.nix"
    assert_success
    run grep "neovim" "$REPO_ROOT/flake.nix"
    assert_success
    run grep "ripgrep" "$REPO_ROOT/flake.nix"
    assert_success
}
