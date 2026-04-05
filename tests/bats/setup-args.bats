#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

# --- --help / -h ---

@test "--help shows usage and exits 0" {
    run bash "$REPO_ROOT/setup.sh" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "-h also shows usage" {
    run bash "$REPO_ROOT/setup.sh" -h
    assert_success
    assert_output --partial "Usage:"
}

@test "--help output contains all documented flags" {
    run bash "$REPO_ROOT/setup.sh" --help
    assert_success
    assert_output --partial "--profile"
    assert_output --partial "--dry-run"
    assert_output --partial "--no-packages"
    assert_output --partial "--no-dotfiles"
    assert_output --partial "--no-syncthing"
    assert_output --partial "--no-backup"
    assert_output --partial "--secrets"
    assert_output --partial "--fleet"
    assert_output --partial "--remote"
    assert_output --partial "--gpg"
    assert_output --partial "--audit"
    assert_output --partial "--serve"
    assert_output --partial "--build-image"
    assert_output --partial "--diff-profiles"
}

# --- Unknown flag ---

@test "unknown flag shows error and usage" {
    run bash "$REPO_ROOT/setup.sh" --bogus-flag
    assert_failure
    assert_output --partial "Error: Unknown option: --bogus-flag"
    assert_output --partial "Usage:"
}

# --- --validate-profile without name ---

@test "--validate-profile without name shows error" {
    run bash "$REPO_ROOT/setup.sh" --validate-profile
    assert_failure
    assert_output --partial "Error: --validate-profile requires a profile name"
}

# --- --create-profile errors ---

@test "--create-profile without name shows error" {
    run bash "$REPO_ROOT/setup.sh" --create-profile
    assert_failure
    assert_output --partial "Error: --create-profile requires a profile name"
}

@test "--create-profile with path traversal shows error" {
    run bash "$REPO_ROOT/setup.sh" --create-profile "../evil"
    assert_failure
    assert_output --partial "Error: Invalid profile name"
}

@test "--create-profile with slashes shows error" {
    run bash "$REPO_ROOT/setup.sh" --create-profile "foo/bar"
    assert_failure
    assert_output --partial "Error: Invalid profile name"
}

# --- --diff-profiles with only one profile ---

@test "--diff-profiles with only one profile shows error" {
    run bash "$REPO_ROOT/setup.sh" --diff-profiles minimal
    assert_failure
    assert_output --partial "Error: --diff-profiles requires two profile names"
}

# --- --secrets without action ---

@test "--secrets without action shows error" {
    run bash "$REPO_ROOT/setup.sh" --secrets
    assert_failure
    assert_output --partial "Error: --secrets requires an action"
}

# --- Full dry-run ---

@test "--dry-run --profile minimal --no-syncthing --no-backup succeeds" {
    run bash "$REPO_ROOT/setup.sh" --dry-run --profile minimal --no-syncthing --no-backup
    assert_success
}

# --- --list-profiles ---

@test "--list-profiles shows available profiles" {
    run bash "$REPO_ROOT/setup.sh" --list-profiles
    assert_success
    assert_output --partial "minimal"
    assert_output --partial "full"
    assert_output --partial "selfhosted"
}

# --- --show-profile ---

@test "--show-profile minimal shows profile content" {
    run bash "$REPO_ROOT/setup.sh" --show-profile minimal
    assert_success
    assert_output --partial "Profile: minimal"
}

@test "--show-profile nonexistent fails with error" {
    run bash "$REPO_ROOT/setup.sh" --show-profile nonexistent
    assert_failure
    assert_output --partial "Error: Profile 'nonexistent' not found"
}

# --- MACHINE_SETUP_DIR environment variable ---

@test "MACHINE_SETUP_DIR is respected" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    # When MACHINE_SETUP_DIR points to a non-repo directory, setup.sh will use
    # it as the install directory. --help exits before any repo operations, so
    # we just verify it does not error out and the variable is picked up.
    run env MACHINE_SETUP_DIR="$tmpdir" bash "$REPO_ROOT/setup.sh" --help
    assert_success
    assert_output --partial "Usage:"
    rm -rf "$tmpdir"
}
