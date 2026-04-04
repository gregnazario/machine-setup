#!/usr/bin/env bats

setup() {
    load '../test_helper'
    TEST_CUSTOM="$(mktemp -d)"
    export MACHINE_SETUP_CUSTOM="$TEST_CUSTOM"
    export REPO_DIR="$REPO_ROOT"
    source "$REPO_ROOT/scripts/load-custom.sh"
}

teardown() {
    rm -rf "$TEST_CUSTOM"
}

@test "discover_custom_profiles with no profiles dir" {
    run discover_custom_profiles
    assert_success
}

@test "discover_custom_profiles finds custom profiles" {
    mkdir -p "$TEST_CUSTOM/profiles"
    cat > "$TEST_CUSTOM/profiles/myprofile.conf" <<'EOF'
[profile]
name = myprofile
description = test
EOF
    run discover_custom_profiles
    assert_output --partial "myprofile"
}

@test "load_custom_packages adds packages from custom configs" {
    mkdir -p "$TEST_CUSTOM/packages"
    cat > "$TEST_CUSTOM/packages/extras.conf" <<'EOF'
[packages]
tools = htop tmux
EOF
    run load_custom_packages "git"
    assert_output --partial "htop"
    assert_output --partial "tmux"
    assert_output --partial "git"
}

@test "load_custom_packages with no packages dir returns input" {
    run load_custom_packages "git neovim"
    assert_output --partial "git"
    assert_output --partial "neovim"
}

@test "run_custom_scripts with no scripts dir succeeds" {
    run run_custom_scripts
    assert_success
}

@test "link_custom_dotfiles with no dotfiles dir succeeds" {
    run link_custom_dotfiles
    assert_success
}

@test "link_custom_dotfiles links files to HOME" {
    export HOME="$(mktemp -d)"
    mkdir -p "$TEST_CUSTOM/dotfiles/.config/myapp"
    echo "test" > "$TEST_CUSTOM/dotfiles/.config/myapp/config.toml"

    link_custom_dotfiles

    assert [ -L "$HOME/.config/myapp/config.toml" ]
    assert [ "$(readlink "$HOME/.config/myapp/config.toml")" = "$TEST_CUSTOM/dotfiles/.config/myapp/config.toml" ]
    rm -rf "$HOME"
}
