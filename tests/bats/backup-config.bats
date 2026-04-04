#!/usr/bin/env bats

setup() {
    load '../test_helper'
    source "$REPO_ROOT/scripts/ini-parser.sh"
}

@test "backup config file exists" {
    assert [ -f "$REPO_ROOT/backup/restic-config.conf" ]
}

@test "backup config has repository section" {
    run ini_get "$REPO_ROOT/backup/restic-config.conf" "repository" "location" ""
    refute_output ""
}

@test "backup config has retention settings" {
    run ini_get "$REPO_ROOT/backup/restic-config.conf" "retention" "keep_daily" ""
    refute_output ""
}

@test "backup config has paths" {
    run ini_get "$REPO_ROOT/backup/restic-config.conf" "paths" "1" ""
    refute_output ""
}

@test "backup script exists and is executable" {
    assert [ -x "$REPO_ROOT/backup/backup.sh" ]
}
