#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "platform-detect.sh contains ChromeOS detection" {
    run grep 'PLATFORM="chromeos"' "$REPO_ROOT/scripts/platform-detect.sh"
    assert_success
}

@test "chromeos.conf platform config exists" {
    assert [ -f "$REPO_ROOT/packages/platforms/chromeos.conf" ]
}

@test "chromeos.conf has correct package manager" {
    source "$REPO_ROOT/scripts/ini-parser.sh"
    run ini_get "$REPO_ROOT/packages/platforms/chromeos.conf" "platform" "package_manager" ""
    assert_output "apt"
}
