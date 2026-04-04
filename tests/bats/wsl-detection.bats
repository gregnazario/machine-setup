#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "platform-detect.sh contains WSL detection" {
    run grep 'PLATFORM="wsl"' "$REPO_ROOT/scripts/platform-detect.sh"
    assert_success
}

@test "wsl.conf platform config exists" {
    assert [ -f "$REPO_ROOT/packages/platforms/wsl.conf" ]
}
