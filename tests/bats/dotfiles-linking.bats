#!/usr/bin/env bats

setup() {
    load '../test_helper'
    source "$REPO_ROOT/scripts/platform-detect.sh"
    source "$REPO_ROOT/scripts/ini-parser.sh"
    source "$REPO_ROOT/scripts/profile-loader.sh"
    detect_platform
}

@test "minimal profile dotfiles directory exists" {
    load_profile "minimal"
    local dotfiles_source
    dotfiles_source=$(ini_get "$PROFILE_FILE" "dotfiles" "source" "")
    assert [ -d "$REPO_ROOT/dotfiles/${dotfiles_source}" ]
}

@test "full profile dotfiles directory exists" {
    load_profile "full"
    local dotfiles_source
    dotfiles_source=$(ini_get "$PROFILE_FILE" "dotfiles" "source" "")
    assert [ -d "$REPO_ROOT/dotfiles/${dotfiles_source}" ]
}
