#!/usr/bin/env bats

setup() {
    load '../test_helper'
    source "$REPO_ROOT/scripts/ini-parser.sh"
}

@test "platform-detect.sh contains NixOS detection" {
    run grep 'PLATFORM="nixos"' "$REPO_ROOT/scripts/platform-detect.sh"
    assert_success
}

@test "nixos.conf has nix package manager" {
    run ini_get "$REPO_ROOT/packages/platforms/nixos.conf" "platform" "package_manager" ""
    assert_output "nix"
}

@test "install-packages.sh has nix installer" {
    run grep "install_packages_nix" "$REPO_ROOT/scripts/install-packages.sh"
    assert_success
}
