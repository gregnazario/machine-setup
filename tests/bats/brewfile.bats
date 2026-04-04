#!/usr/bin/env bats

setup() {
    load '../test_helper'
    source "$REPO_ROOT/scripts/platform-detect.sh"
    source "$REPO_ROOT/scripts/ini-parser.sh"
    source "$REPO_ROOT/scripts/profile-loader.sh"
    source "$REPO_ROOT/scripts/install-packages.sh"
    detect_platform
}

@test "generate_brewfile creates valid Brewfile content" {
    run generate_brewfile "git neovim ripgrep"
    assert_success
    assert_output --partial 'brew "git"'
    assert_output --partial 'brew "neovim"'
    assert_output --partial 'brew "ripgrep"'
}

@test "generate_brewfile handles empty input" {
    run generate_brewfile ""
    assert_success
    refute_output --partial 'brew "'
}
