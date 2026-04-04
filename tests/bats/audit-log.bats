#!/usr/bin/env bats

setup() {
    load '../test_helper'
    TEST_DIR="$(mktemp -d)"
    export MACHINE_SETUP_DIR="$TEST_DIR"
    export PLATFORM="test-platform"
    export PROFILE="test-profile"
    source "$REPO_ROOT/scripts/audit-log.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "audit-log.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/audit-log.sh" ]
}

@test "audit_log creates log file and writes entry" {
    audit_log "test-action" "test detail" "info"
    assert [ -f "$TEST_DIR/audit.log" ]
    run cat "$TEST_DIR/audit.log"
    assert_output --partial "test-action"
    assert_output --partial "test detail"
}

@test "audit_setup_start logs setup start" {
    audit_setup_start "--profile minimal --dry-run"
    run cat "$TEST_DIR/audit.log"
    assert_output --partial "setup-start"
    assert_output --partial "--profile minimal"
}

@test "audit_setup_complete logs success" {
    audit_setup_complete "profile=minimal"
    run cat "$TEST_DIR/audit.log"
    assert_output --partial "setup-complete"
    assert_output --partial "success"
}

@test "audit_show displays entries" {
    audit_log "action1" "detail1" "info"
    audit_log "action2" "detail2" "success"
    run audit_show 10
    assert_output --partial "action1"
    assert_output --partial "action2"
}

@test "setup.sh --help mentions --audit" {
    cd "$REPO_ROOT"
    run bash setup.sh --help
    assert_output --partial "--audit"
}
