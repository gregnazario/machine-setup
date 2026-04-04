#!/usr/bin/env bats

setup() {
    load '../test_helper'
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"
    export SHELL="/bin/bash"
    export REPO_DIR="$REPO_ROOT"
    source "$REPO_ROOT/scripts/install-completions.sh"
}

teardown() {
    rm -rf "$TEST_HOME"
}

@test "install-completions.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/install-completions.sh" ]
}

@test "bash completion installs symlink" {
    install_bash_completion
    local target="$TEST_HOME/.bash_completion.d/setup.sh"
    assert [ -L "$target" ]
}

@test "zsh completion installs symlink" {
    install_zsh_completion
    local target="$TEST_HOME/.zsh/completions/_setup.sh"
    assert [ -L "$target" ]
}

@test "fish completion installs symlink" {
    install_fish_completion
    local target="$TEST_HOME/.config/fish/completions/setup.sh.fish"
    assert [ -L "$target" ]
}

@test "dry-run mode does not create files" {
    DRY_RUN=true
    run install_bash_completion
    assert_output --partial "Would install"
    assert [ ! -e "$TEST_HOME/.bash_completion.d/setup.sh" ]
}

@test "detect_and_install picks bash for SHELL=/bin/bash" {
    export SHELL="/bin/bash"
    detect_and_install
    assert [ -L "$TEST_HOME/.bash_completion.d/setup.sh" ]
}
