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

    # Copy the example file too
    cp "$REPO_ROOT/secrets.conf.example" "$TEST_DIR/secrets.conf.example"

    # Source the orchestrator for function-level tests
    source "$TEST_DIR/scripts/secrets/secrets-manager.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ── File existence ──────────────────────────────────────────────────────────

@test "secrets-manager.sh exists and is executable" {
    [[ -x "$REPO_ROOT/scripts/secrets/secrets-manager.sh" ]]
}

# ── load_secret_mappings ────────────────────────────────────────────────────

@test "load_secret_mappings reads all secret sections" {
    load_secret_mappings "$TEST_DIR/secrets.conf"
    assert_equal "${#SECRET_NAMES[@]}" 3
}

@test "load_secret_mappings populates correct names" {
    load_secret_mappings "$TEST_DIR/secrets.conf"
    assert_equal "${SECRET_NAMES[0]}" "restic-password"
    assert_equal "${SECRET_NAMES[1]}" "ssh-key"
    assert_equal "${SECRET_NAMES[2]}" "github-token"
}

@test "load_secret_mappings ignores non-secret sections" {
    cat > "$TEST_DIR/minimal.conf" <<'EOF'
[provider]
name = test

[other]
key = value

[secret.only-one]
provider_key = Test
dest = env
dest_var = TEST
EOF
    load_secret_mappings "$TEST_DIR/minimal.conf"
    assert_equal "${#SECRET_NAMES[@]}" 1
    assert_equal "${SECRET_NAMES[0]}" "only-one"
}

# ── get_secret_config ───────────────────────────────────────────────────────

@test "get_secret_config reads ini destination fields" {
    get_secret_config "$TEST_DIR/secrets.conf" "restic-password"
    assert_equal "$SECRET_PROVIDER_KEY" "Restic Backup Password"
    assert_equal "$SECRET_DEST" "ini"
    assert_equal "$SECRET_DEST_FILE" "backup/restic-config.conf"
    assert_equal "$SECRET_DEST_SECTION" "restic"
    assert_equal "$SECRET_DEST_KEY" "password"
}

@test "get_secret_config reads file destination fields" {
    get_secret_config "$TEST_DIR/secrets.conf" "ssh-key"
    assert_equal "$SECRET_PROVIDER_KEY" "SSH Private Key"
    assert_equal "$SECRET_DEST" "file"
    assert_equal "$SECRET_DEST_FILE" "~/.ssh/id_ed25519"
    assert_equal "$SECRET_DEST_MODE" "0600"
}

@test "get_secret_config reads env destination fields" {
    get_secret_config "$TEST_DIR/secrets.conf" "github-token"
    assert_equal "$SECRET_PROVIDER_KEY" "GitHub PAT"
    assert_equal "$SECRET_DEST" "env"
    assert_equal "$SECRET_DEST_VAR" "GITHUB_TOKEN"
}

@test "get_secret_config defaults dest_mode to 0600" {
    # restic-password has no dest_mode set
    get_secret_config "$TEST_DIR/secrets.conf" "restic-password"
    assert_equal "$SECRET_DEST_MODE" "0600"
}

# ── list_secrets ────────────────────────────────────────────────────────────

@test "list_secrets outputs a table with headers" {
    run list_secrets "$TEST_DIR/secrets.conf"
    assert_success
    assert_line --index 0 --partial "NAME"
    assert_line --index 0 --partial "DEST"
    assert_line --index 0 --partial "PROVIDER KEY"
}

@test "list_secrets shows all configured secrets" {
    run list_secrets "$TEST_DIR/secrets.conf"
    assert_success
    assert_output --partial "restic-password"
    assert_output --partial "ssh-key"
    assert_output --partial "github-token"
}

@test "list_secrets shows dest type for each entry" {
    run list_secrets "$TEST_DIR/secrets.conf"
    assert_success
    assert_output --partial "ini"
    assert_output --partial "file"
    assert_output --partial "env"
}

# ── detect_provider ─────────────────────────────────────────────────────────

@test "detect_provider returns empty when no providers available" {
    run detect_provider "$TEST_DIR/secrets.conf"
    assert_success
    assert_output ""
}

@test "detect_provider returns empty with unconfigured provider" {
    cat > "$TEST_DIR/no-provider.conf" <<'EOF'
[provider]

[secret.test]
provider_key = Test
dest = env
dest_var = TEST
EOF
    run detect_provider "$TEST_DIR/no-provider.conf"
    assert_success
    assert_output ""
}

@test "detect_provider returns configured provider when script exists and available" {
    # Create a fake provider that reports available
    mkdir -p "$TEST_DIR/scripts/secrets/providers"
    cat > "$TEST_DIR/scripts/secrets/providers/1password.sh" <<'PROVIDER'
provider_available() { return 0; }
provider_get_secret() { echo "mock-value"; }
PROVIDER
    # Re-set PROVIDERS_DIR for this test
    PROVIDERS_DIR="$TEST_DIR/scripts/secrets/providers"
    run detect_provider "$TEST_DIR/secrets.conf"
    assert_success
    assert_output "1password"
}

# ── CLI usage ───────────────────────────────────────────────────────────────

@test "secrets-manager.sh without args shows usage" {
    run env -u _COMMON_SH_LOADED -u _SECRET_ROUTING_SH_LOADED REPO_DIR="$TEST_DIR" \
        bash "$TEST_DIR/scripts/secrets/secrets-manager.sh"
    assert_failure
    assert_output --partial "Usage:"
    assert_output --partial "pull"
    assert_output --partial "push"
}

@test "secrets-manager.sh --help shows usage" {
    run env -u _COMMON_SH_LOADED -u _SECRET_ROUTING_SH_LOADED REPO_DIR="$TEST_DIR" \
        bash "$TEST_DIR/scripts/secrets/secrets-manager.sh" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "secrets-manager.sh list with --conf works" {
    run env -u _COMMON_SH_LOADED -u _SECRET_ROUTING_SH_LOADED REPO_DIR="$TEST_DIR" \
        bash "$TEST_DIR/scripts/secrets/secrets-manager.sh" list --conf "$TEST_DIR/secrets.conf"
    assert_success
    assert_output --partial "restic-password"
}

# ── init action ─────────────────────────────────────────────────────────────

@test "init creates secrets.conf from example" {
    rm -f "$TEST_DIR/secrets.conf"
    run env -u _COMMON_SH_LOADED -u _SECRET_ROUTING_SH_LOADED REPO_DIR="$TEST_DIR" \
        bash "$TEST_DIR/scripts/secrets/secrets-manager.sh" init --conf "$TEST_DIR/secrets.conf"
    assert_success
    [[ -f "$TEST_DIR/secrets.conf" ]]
}

@test "init does not overwrite existing secrets.conf" {
    run env -u _COMMON_SH_LOADED -u _SECRET_ROUTING_SH_LOADED REPO_DIR="$TEST_DIR" \
        bash "$TEST_DIR/scripts/secrets/secrets-manager.sh" init --conf "$TEST_DIR/secrets.conf"
    assert_success
    assert_output --partial "already exists"
}

# ── secrets_status ──────────────────────────────────────────────────────────

@test "secrets_status outputs a table" {
    run secrets_status "$TEST_DIR/secrets.conf"
    assert_success
    assert_output --partial "NAME"
    assert_output --partial "PROVIDER"
    assert_output --partial "LOCAL"
}
