#!/usr/bin/env bats

setup() {
    load '../test_helper'
    source "$REPO_ROOT/scripts/version-pin.sh"
}

@test "parse_package_spec handles plain package name" {
    parse_package_spec "git"
    assert [ "$PKG_NAME" = "git" ]
    assert [ "$PKG_VERSION" = "" ]
}

@test "parse_package_spec handles exact version" {
    parse_package_spec "docker=24.0.7"
    assert [ "$PKG_NAME" = "docker" ]
    assert [ "$PKG_CONSTRAINT" = "=" ]
    assert [ "$PKG_VERSION" = "24.0.7" ]
}

@test "parse_package_spec handles >= constraint" {
    parse_package_spec "kubectl>=1.28"
    assert [ "$PKG_NAME" = "kubectl" ]
    assert [ "$PKG_CONSTRAINT" = ">=" ]
    assert [ "$PKG_VERSION" = "1.28" ]
}

@test "parse_package_spec handles wildcard version" {
    parse_package_spec "docker=24.0.*"
    assert [ "$PKG_NAME" = "docker" ]
    assert [ "$PKG_VERSION" = "24.0.*" ]
}

@test "format_versioned_package with apt uses = syntax" {
    run format_versioned_package "docker" "=" "24.0.7" "apt"
    assert_output "docker=24.0.7"
}

@test "format_versioned_package with dnf uses - syntax" {
    run format_versioned_package "docker" "=" "24.0.7" "dnf"
    assert_output "docker-24.0.7"
}

@test "format_versioned_package without version returns plain name" {
    run format_versioned_package "git" "" "" "apt"
    assert_output "git"
}

@test "process_versioned_packages handles mixed list" {
    run process_versioned_packages "git docker=24.0.7 neovim" "apt"
    assert_output --partial "git"
    assert_output --partial "docker=24.0.7"
    assert_output --partial "neovim"
}

@test "format_versioned_package with homebrew strips version" {
    run format_versioned_package "docker" "=" "24.0.7" "homebrew"
    assert_line "docker"
    assert_output --partial "WARN"
}

@test "parse_package_spec handles gentoo category/package" {
    parse_package_spec "sys-apps/fd=8.7.0"
    assert [ "$PKG_NAME" = "sys-apps/fd" ]
    assert [ "$PKG_VERSION" = "8.7.0" ]
}
