#!/usr/bin/env bats

setup() {
    load '../test_helper'
    source "$REPO_ROOT/scripts/ini-parser.sh"
}

@test "all platform configs have name field" {
    for conf in "$REPO_ROOT"/packages/platforms/*.conf; do
        local name
        name=$(ini_get "$conf" "platform" "name" "")
        [ -n "$name" ] || fail "Missing name in $(basename "$conf")"
    done
}

@test "all platform configs have package_manager field" {
    for conf in "$REPO_ROOT"/packages/platforms/*.conf; do
        local pm
        pm=$(ini_get "$conf" "platform" "package_manager" "")
        [ -n "$pm" ] || fail "Missing package_manager in $(basename "$conf")"
    done
}
