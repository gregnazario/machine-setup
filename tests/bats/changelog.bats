#!/usr/bin/env bats

setup() {
    load '../test_helper'
}

@test "generate-changelog.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/generate-changelog.sh" ]
}

@test "generate-changelog.sh produces output" {
    local tmp
    tmp=$(mktemp)
    run bash "$REPO_ROOT/scripts/generate-changelog.sh" "$tmp"
    assert_success
    assert [ -s "$tmp" ]
    rm -f "$tmp"
}

@test "generated changelog has expected structure" {
    local tmp
    tmp=$(mktemp)
    bash "$REPO_ROOT/scripts/generate-changelog.sh" "$tmp"
    run cat "$tmp"
    assert_output --partial "# Changelog"
    # Should have at least one categorized section (depends on git history)
    [[ "$output" == *"## "* ]]
    rm -f "$tmp"
}

@test "generated changelog contains commit references" {
    local tmp
    tmp=$(mktemp)
    bash "$REPO_ROOT/scripts/generate-changelog.sh" "$tmp"
    # Should have at least one backtick-wrapped short hash
    run grep -c '`[a-f0-9]\{7\}`' "$tmp"
    [ "$output" -gt 0 ]
    rm -f "$tmp"
}
