#!/usr/bin/env bats

setup() {
    load '../test_helper'
    source "$REPO_ROOT/scripts/platform-detect.sh"
    source "$REPO_ROOT/scripts/profile-loader.sh"
    source "$REPO_ROOT/scripts/install-packages.sh"
    detect_platform
}

@test "fd-find gets mapped for current platform" {
    run get_mapped_package_name "fd-find"
    refute_output ""
}

@test "collect_packages returns packages for minimal profile" {
    load_profile "minimal"
    run collect_packages
    assert_output --partial "git"
}

@test "collect_packages includes nushell for minimal profile" {
    load_profile "minimal"
    run collect_packages
    assert_output --partial "nushell"
}
