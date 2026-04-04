#!/usr/bin/env bats

setup() {
    load '../test_helper'
    source "$REPO_ROOT/scripts/ini-parser.sh"
    TEST_INI="$(mktemp)"
    cat > "$TEST_INI" <<'EOINI'
[section1]
key1 = value1
key2 = value2 # this is a comment
key3 = value with spaces
key4 = value4 ; semicolon comment

[section2]
name = test
EOINI
}

teardown() {
    rm -f "$TEST_INI"
}

@test "ini_get retrieves basic key" {
    run ini_get "$TEST_INI" "section1" "key1" ""
    assert_output "value1"
}

@test "ini_get strips inline hash comment" {
    run ini_get "$TEST_INI" "section1" "key2" ""
    assert_output "value2"
}

@test "ini_get strips inline semicolon comment" {
    run ini_get "$TEST_INI" "section1" "key4" ""
    assert_output "value4"
}

@test "ini_get preserves value with spaces" {
    run ini_get "$TEST_INI" "section1" "key3" ""
    assert_output "value with spaces"
}

@test "ini_get returns default for missing key" {
    run ini_get "$TEST_INI" "section1" "missing" "default_val"
    assert_output "default_val"
}

@test "ini_get isolates sections" {
    run ini_get "$TEST_INI" "section2" "name" ""
    assert_output "test"
}

@test "ini_get preserves hash in URL without leading space" {
    local url_ini="$(mktemp)"
    cat > "$url_ini" <<'EOINI'
[urls]
site = https://example.com#anchor
EOINI
    run ini_get "$url_ini" "urls" "site" ""
    assert_output "https://example.com#anchor"
    rm -f "$url_ini"
}

@test "ini_get_sections lists all sections" {
    run ini_get_sections "$TEST_INI"
    assert_output --partial "section1"
    assert_output --partial "section2"
}
