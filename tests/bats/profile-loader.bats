#!/usr/bin/env bats

setup() {
    load '../test_helper'
    source "$REPO_ROOT/scripts/platform-detect.sh"
    source "$REPO_ROOT/scripts/ini-parser.sh"
    source "$REPO_ROOT/scripts/profile-loader.sh"
}

@test "load minimal profile sets PROFILE_NAME" {
    load_profile "minimal"
    assert [ "$PROFILE_NAME" = "minimal" ]
}

@test "minimal profile has nushell" {
    load_profile "minimal"
    run get_profile_packages
    assert_output --partial "nushell"
}

@test "minimal profile has neovim" {
    load_profile "minimal"
    run get_profile_packages
    assert_output --partial "neovim"
}

@test "full profile has zellij" {
    load_profile "full"
    run get_profile_packages
    assert_output --partial "zellij"
}

@test "full profile inherits nushell from minimal" {
    load_profile "full"
    run get_profile_packages
    assert_output --partial "nushell"
}

@test "profile has description field" {
    load_profile "minimal"
    run ini_get "$PROFILE_FILE" "profile" "description" ""
    refute_output ""
}
