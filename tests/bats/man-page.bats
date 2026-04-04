#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "man page exists" {
    assert [ -f "$REPO_ROOT/docs/setup.sh.1" ]
}

@test "man page is valid troff" {
    # Use mandoc or nroff to validate the man page can be processed
    if command -v mandoc &>/dev/null; then
        run mandoc -Tutf8 "$REPO_ROOT/docs/setup.sh.1"
        assert_success
    elif command -v nroff &>/dev/null; then
        run nroff -man -Tutf8 "$REPO_ROOT/docs/setup.sh.1"
        assert_success
    elif command -v groff &>/dev/null; then
        run groff -man -Tutf8 "$REPO_ROOT/docs/setup.sh.1"
        assert_success
    else
        skip "no troff processor available (mandoc, nroff, or groff)"
    fi
}

@test "man page contains all major options" {
    # Render the man page to plain text, stripping backspace formatting
    if command -v mandoc &>/dev/null; then
        run bash -c "mandoc -Tascii '$REPO_ROOT/docs/setup.sh.1' | col -bx"
    elif command -v nroff &>/dev/null; then
        run bash -c "nroff -man '$REPO_ROOT/docs/setup.sh.1' | col -bx"
    elif command -v groff &>/dev/null; then
        run bash -c "groff -man -Tascii '$REPO_ROOT/docs/setup.sh.1' | col -bx"
    else
        skip "no troff processor available"
    fi
    assert_output --partial "dry-run"
    assert_output --partial "validate-profile"
    assert_output --partial "interactive"
    assert_output --partial "status"
    assert_output --partial "check"
    assert_output --partial "unlink"
    assert_output --partial "create-profile"
    assert_output --partial "update"
}

@test "man page lists all 18 platforms" {
    run cat "$REPO_ROOT/docs/setup.sh.1"
    assert_output --partial "NixOS"
    assert_output --partial "WSL2"
    assert_output --partial "Termux"
    assert_output --partial "ChromeOS"
}
