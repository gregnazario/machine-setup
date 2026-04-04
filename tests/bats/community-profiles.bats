#!/usr/bin/env bats

setup() {
    load '../test_helper'
    source "$REPO_ROOT/scripts/ini-parser.sh"
}

@test "data-science profile exists and has required fields" {
    local conf="$REPO_ROOT/profiles/community/data-science.conf"
    assert [ -f "$conf" ]
    run ini_get "$conf" "profile" "name" ""
    assert_output "data-science"
    run ini_get "$conf" "profile" "extends" ""
    assert_output "full"
}

@test "devops profile exists and has required fields" {
    local conf="$REPO_ROOT/profiles/community/devops.conf"
    assert [ -f "$conf" ]
    run ini_get "$conf" "profile" "name" ""
    assert_output "devops"
}

@test "homelab profile exists and extends selfhosted" {
    local conf="$REPO_ROOT/profiles/community/homelab.conf"
    assert [ -f "$conf" ]
    run ini_get "$conf" "profile" "extends" ""
    assert_output "selfhosted"
}

@test "creative profile exists and has required fields" {
    local conf="$REPO_ROOT/profiles/community/creative.conf"
    assert [ -f "$conf" ]
    run ini_get "$conf" "profile" "name" ""
    assert_output "creative"
}

@test "all community profiles have description" {
    for conf in "$REPO_ROOT"/profiles/community/*.conf; do
        [[ -f "$conf" ]] || continue
        local desc
        desc=$(ini_get "$conf" "profile" "description" "")
        [ -n "$desc" ] || fail "Missing description in $(basename "$conf")"
    done
}

@test "community README exists" {
    assert [ -f "$REPO_ROOT/profiles/community/README.md" ]
}
