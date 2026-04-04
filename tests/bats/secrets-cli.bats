#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "setup.sh --help mentions --secrets" {
    cd "$REPO_ROOT"
    run bash setup.sh --help
    assert_output --partial "--secrets"
}

@test "setup.sh --secrets without action shows error" {
    cd "$REPO_ROOT"
    run bash setup.sh --secrets
    assert_failure
    assert_output --partial "requires an action"
}

@test "secrets-manager.sh list without conf shows error" {
    cd "$REPO_ROOT"
    # Ensure no secrets.conf
    rm -f "$REPO_ROOT/secrets.conf"
    run bash scripts/secrets/secrets-manager.sh list
    assert_failure
    assert_output --partial "secrets.conf"
}

@test "secrets-manager.sh init creates secrets.conf from example" {
    cd "$REPO_ROOT"
    rm -f "$REPO_ROOT/secrets.conf"
    run bash scripts/secrets/secrets-manager.sh init
    assert_success
    assert [ -f "$REPO_ROOT/secrets.conf" ]
    # Clean up
    rm -f "$REPO_ROOT/secrets.conf"
}

@test "secrets-manager.sh set-provider without name shows usage error" {
    cd "$REPO_ROOT"
    # set-provider needs secrets.conf to exist
    bash scripts/secrets/secrets-manager.sh init 2>/dev/null || true
    run bash scripts/secrets/secrets-manager.sh set-provider
    assert_failure
    assert_output --partial "set-provider"
    # Clean up
    rm -f "$REPO_ROOT/secrets.conf"
}

@test "secrets-manager.sh set-provider updates provider in config" {
    cd "$REPO_ROOT"
    bash scripts/secrets/secrets-manager.sh init 2>/dev/null || true
    run bash scripts/secrets/secrets-manager.sh set-provider bitwarden
    assert_success
    assert_output --partial "bitwarden"
    # Clean up
    rm -f "$REPO_ROOT/secrets.conf"
}
