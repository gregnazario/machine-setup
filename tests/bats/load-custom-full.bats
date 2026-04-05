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
    if [[ -n "${TEST_HOME:-}" ]]; then
        rm -rf "$TEST_HOME"
    fi
}

# --- run_custom_scripts ---

@test "run_custom_scripts executes scripts in alphabetical order" {
    mkdir -p "$TEST_CUSTOM/scripts"
    local outfile="$TEST_CUSTOM/order.txt"

    cat > "$TEST_CUSTOM/scripts/01-first.sh" <<EOF
#!/usr/bin/env bash
echo "first" >> "$outfile"
EOF
    cat > "$TEST_CUSTOM/scripts/02-second.sh" <<EOF
#!/usr/bin/env bash
echo "second" >> "$outfile"
EOF
    chmod +x "$TEST_CUSTOM/scripts/01-first.sh"
    chmod +x "$TEST_CUSTOM/scripts/02-second.sh"

    run_custom_scripts

    assert [ -f "$outfile" ]
    run cat "$outfile"
    assert_line -n 0 "first"
    assert_line -n 1 "second"
}

@test "run_custom_scripts skips non-executable scripts" {
    mkdir -p "$TEST_CUSTOM/scripts"
    local outfile="$TEST_CUSTOM/order.txt"

    cat > "$TEST_CUSTOM/scripts/01-runs.sh" <<EOF
#!/usr/bin/env bash
echo "ran" >> "$outfile"
EOF
    cat > "$TEST_CUSTOM/scripts/02-skipped.sh" <<EOF
#!/usr/bin/env bash
echo "skipped" >> "$outfile"
EOF
    chmod +x "$TEST_CUSTOM/scripts/01-runs.sh"
    # 02-skipped.sh intentionally not executable

    run_custom_scripts

    assert [ -f "$outfile" ]
    run cat "$outfile"
    assert_output "ran"
    refute_output --partial "skipped"
}

@test "run_custom_scripts in dry-run mode prints but does not execute" {
    mkdir -p "$TEST_CUSTOM/scripts"
    local outfile="$TEST_CUSTOM/output.txt"

    cat > "$TEST_CUSTOM/scripts/01-test.sh" <<EOF
#!/usr/bin/env bash
echo "executed" >> "$outfile"
EOF
    chmod +x "$TEST_CUSTOM/scripts/01-test.sh"

    export DRY_RUN=true
    run run_custom_scripts

    assert_success
    assert_output --partial "Would run custom script: 01-test.sh"
    assert [ ! -f "$outfile" ]
}

# --- link_custom_dotfiles ---

@test "link_custom_dotfiles creates symlinks mirroring directory structure" {
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"

    mkdir -p "$TEST_CUSTOM/dotfiles/.config/app1"
    mkdir -p "$TEST_CUSTOM/dotfiles/.config/app2"
    echo "cfg1" > "$TEST_CUSTOM/dotfiles/.config/app1/settings.toml"
    echo "cfg2" > "$TEST_CUSTOM/dotfiles/.config/app2/config.yaml"

    link_custom_dotfiles

    assert [ -L "$HOME/.config/app1/settings.toml" ]
    assert [ -L "$HOME/.config/app2/config.yaml" ]
    assert [ "$(readlink "$HOME/.config/app1/settings.toml")" = "$TEST_CUSTOM/dotfiles/.config/app1/settings.toml" ]
    assert [ "$(readlink "$HOME/.config/app2/config.yaml")" = "$TEST_CUSTOM/dotfiles/.config/app2/config.yaml" ]
}

@test "link_custom_dotfiles is idempotent" {
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"

    mkdir -p "$TEST_CUSTOM/dotfiles/.config/myapp"
    echo "data" > "$TEST_CUSTOM/dotfiles/.config/myapp/conf.toml"

    link_custom_dotfiles
    # Run a second time — should not break the existing link
    link_custom_dotfiles

    assert [ -L "$HOME/.config/myapp/conf.toml" ]
    assert [ "$(readlink "$HOME/.config/myapp/conf.toml")" = "$TEST_CUSTOM/dotfiles/.config/myapp/conf.toml" ]
    assert_equal "$(cat "$HOME/.config/myapp/conf.toml")" "data"
}

@test "link_custom_dotfiles backs up existing non-symlink files" {
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"

    mkdir -p "$TEST_CUSTOM/dotfiles/.config/myapp"
    echo "new content" > "$TEST_CUSTOM/dotfiles/.config/myapp/conf.toml"

    # Create a pre-existing real file at the target location
    mkdir -p "$HOME/.config/myapp"
    echo "old content" > "$HOME/.config/myapp/conf.toml"

    link_custom_dotfiles

    # The target should now be a symlink
    assert [ -L "$HOME/.config/myapp/conf.toml" ]
    # A backup file should exist
    local backup
    backup=$(find "$HOME/.config/myapp" -name 'conf.toml.backup.*' | head -1)
    assert [ -n "$backup" ]
    assert_equal "$(cat "$backup")" "old content"
}

@test "link_custom_dotfiles in dry-run mode does not create links" {
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"

    mkdir -p "$TEST_CUSTOM/dotfiles/.config/myapp"
    echo "data" > "$TEST_CUSTOM/dotfiles/.config/myapp/conf.toml"

    export DRY_RUN=true
    run link_custom_dotfiles

    assert_success
    assert_output --partial "Would link:"
    assert [ ! -L "$HOME/.config/myapp/conf.toml" ]
}

# --- load_custom_packages ---

@test "load_custom_packages deduplicates packages" {
    mkdir -p "$TEST_CUSTOM/packages"
    cat > "$TEST_CUSTOM/packages/set1.conf" <<'EOF'
[packages]
tools = htop git tmux
EOF
    cat > "$TEST_CUSTOM/packages/set2.conf" <<'EOF'
[packages]
tools = git curl htop
EOF
    run load_custom_packages "git"
    # Each package should appear exactly once
    local count
    count=$(echo "$output" | tr ' ' '\n' | grep -c '^git$' || true)
    assert_equal "$count" "1"
    assert_output --partial "curl"
    assert_output --partial "tmux"
    assert_output --partial "htop"
}

# --- discover_custom_profiles ---

@test "discover_custom_profiles counts correctly with multiple profiles" {
    mkdir -p "$TEST_CUSTOM/profiles"
    echo "[profile]" > "$TEST_CUSTOM/profiles/dev.conf"
    echo "[profile]" > "$TEST_CUSTOM/profiles/server.conf"
    echo "[profile]" > "$TEST_CUSTOM/profiles/desktop.conf"

    run discover_custom_profiles
    assert_success
    assert_output --partial "dev"
    assert_output --partial "server"
    assert_output --partial "desktop"
    assert_output --partial "Discovered 3 custom profile(s)"
}
