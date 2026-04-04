#!/usr/bin/env bats

setup() {
    load '../test_helper'

    # Create a fake repo structure in a temp dir
    TEST_DIR="$(mktemp -d)"
    export REPO_DIR="$TEST_DIR"
    export _SECRET_ROUTING_SH_LOADED=""
    export _COMMON_SH_LOADED=""

    # Create required script dirs so sourcing works
    mkdir -p "$TEST_DIR/scripts/lib"
    mkdir -p "$TEST_DIR/scripts/secrets/providers"
    mkdir -p "$TEST_DIR/dotfiles"
    cp "$REPO_ROOT/scripts/lib/common.sh" "$TEST_DIR/scripts/lib/common.sh"
    cp "$REPO_ROOT/scripts/ini-parser.sh" "$TEST_DIR/scripts/ini-parser.sh"
    cp "$REPO_ROOT/scripts/secrets/secret-routing.sh" "$TEST_DIR/scripts/secrets/secret-routing.sh"
    cp "$REPO_ROOT/scripts/secrets/secrets-manager.sh" "$TEST_DIR/scripts/secrets/secrets-manager.sh"

    # Create a .gitattributes (needed by secret-routing)
    cat > "$TEST_DIR/dotfiles/.gitattributes" <<'EOF'
secrets/** filter=git-crypt diff=git-crypt
EOF

    # Create a test secrets.conf
    cat > "$TEST_DIR/secrets.conf" <<'EOF'
[provider]
name = 1password
vault = Personal

[secret.restic-password]
provider_key = Restic Backup Password
dest = ini
dest_file = backup/restic-config.conf
dest_section = restic
dest_key = password

[secret.ssh-key]
provider_key = SSH Private Key
dest = file
dest_file = ~/.ssh/id_ed25519
dest_mode = 0600

[secret.github-token]
provider_key = GitHub PAT
dest = env
dest_var = GITHUB_TOKEN
EOF

    # Source the orchestrator for function-level tests
    source "$TEST_DIR/scripts/secrets/secrets-manager.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ── generate_random_secret ──────────────────────────────────────────────────

@test "generate_random_secret produces output of correct length" {
    run generate_random_secret 16
    assert_success
    [ "${#output}" -eq 16 ]
}

@test "generate_random_secret defaults to 32 characters" {
    run generate_random_secret
    assert_success
    [ "${#output}" -eq 32 ]
}

@test "generate_random_secret produces different values" {
    local val1 val2
    val1=$(generate_random_secret 32)
    val2=$(generate_random_secret 32)
    [ "$val1" != "$val2" ]
}

@test "generate_random_secret output contains only allowed characters" {
    local val
    val=$(generate_random_secret 64)
    # Should only contain A-Za-z0-9!@#$%^&*
    [[ "$val" =~ ^[A-Za-z0-9\!\@\#\$\%\^\&\*]+$ ]]
}

# ── secrets-manager.sh rotate action ────────────────────────────────────────

@test "secrets-manager.sh accepts rotate action" {
    run grep "rotate)" "$REPO_ROOT/scripts/secrets/secrets-manager.sh"
    assert_success
}

@test "rotate_secrets skips ssh key files" {
    run rotate_secrets "$TEST_DIR/secrets.conf" "true" ""
    assert_success
    assert_output --partial "Skipping ssh-key"
}

@test "rotate_secrets dry-run does not modify anything" {
    run rotate_secrets "$TEST_DIR/secrets.conf" "true" ""
    assert_success
    assert_output --partial "Would rotate"
    assert_output --partial "skipped"
}

@test "rotate_secrets can target a specific secret" {
    run rotate_secrets "$TEST_DIR/secrets.conf" "true" "restic-password"
    assert_success
    assert_output --partial "Would rotate: restic-password"
    # Should not mention other secrets (except in summary)
    refute_output --partial "Would rotate: github-token"
}

@test "usage includes rotate action" {
    run _usage
    assert_success
    assert_output --partial "rotate"
}
