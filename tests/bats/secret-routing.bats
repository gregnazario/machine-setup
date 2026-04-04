#!/usr/bin/env bats

setup() {
    load '../test_helper'

    # Create a fake repo structure in a temp dir
    FAKE_REPO="$(mktemp -d)"
    export REPO_DIR="$FAKE_REPO"
    export _SECRET_ROUTING_SH_LOADED=""
    export _COMMON_SH_LOADED=""

    # Create a .gitattributes
    mkdir -p "$FAKE_REPO/dotfiles"
    cat > "$FAKE_REPO/dotfiles/.gitattributes" <<'EOF'
# Secrets
secrets/** filter=git-crypt diff=git-crypt
**/secrets/** filter=git-crypt diff=git-crypt

# SSH keys
**/.ssh/id_* filter=git-crypt diff=git-crypt

# Backup config with passwords
backup/restic-config.conf filter=git-crypt diff=git-crypt

# Don't encrypt these
.gitattributes !filter !diff
EOF

    # Create required script dirs so sourcing works
    mkdir -p "$FAKE_REPO/scripts/lib"
    mkdir -p "$FAKE_REPO/scripts/secrets"
    cp "$REPO_ROOT/scripts/lib/common.sh" "$FAKE_REPO/scripts/lib/common.sh"
    cp "$REPO_ROOT/scripts/ini-parser.sh" "$FAKE_REPO/scripts/ini-parser.sh"
    cp "$REPO_ROOT/scripts/secrets/secret-routing.sh" "$FAKE_REPO/scripts/secrets/secret-routing.sh"

    source "$FAKE_REPO/scripts/secrets/secret-routing.sh"
}

teardown() {
    rm -rf "$FAKE_REPO"
}

# ── is_git_crypt_protected ──────────────────────────────────────────────────

@test "is_git_crypt_protected: exact path match" {
    run is_git_crypt_protected "backup/restic-config.conf"
    assert_success
}

@test "is_git_crypt_protected: single-star glob (secrets/*)" {
    run is_git_crypt_protected "secrets/api-key.txt"
    assert_success
}

@test "is_git_crypt_protected: double-star glob (secrets/**)" {
    run is_git_crypt_protected "secrets/nested/deep/file.txt"
    assert_success
}

@test "is_git_crypt_protected: double-star prefix (**/.ssh/id_*)" {
    run is_git_crypt_protected "home/.ssh/id_rsa"
    assert_success
}

@test "is_git_crypt_protected: double-star prefix with deeper nesting" {
    run is_git_crypt_protected "users/john/.ssh/id_ed25519"
    assert_success
}

@test "is_git_crypt_protected: **/secrets/** matches nested" {
    run is_git_crypt_protected "some/dir/secrets/key.pem"
    assert_success
}

@test "is_git_crypt_protected: unprotected path returns failure" {
    run is_git_crypt_protected "README.md"
    assert_failure
}

@test "is_git_crypt_protected: unprotected path in random dir" {
    run is_git_crypt_protected "scripts/setup.sh"
    assert_failure
}

@test "is_git_crypt_protected: negation rule (!filter) not treated as protected" {
    run is_git_crypt_protected ".gitattributes"
    assert_failure
}

# ── route_to_ini ────────────────────────────────────────────────────────────

@test "route_to_ini: creates INI file and writes key" {
    local ini_file="$FAKE_REPO/secrets/config.ini"
    mkdir -p "$FAKE_REPO/secrets"

    run route_to_ini "s3cret" "$ini_file" "database" "password"
    assert_success

    run ini_get "$ini_file" "database" "password"
    assert_output "s3cret"
}

@test "route_to_ini: updates existing key in INI file" {
    local ini_file="$FAKE_REPO/secrets/config.ini"
    mkdir -p "$FAKE_REPO/secrets"

    cat > "$ini_file" <<'EOF'
[database]
host = localhost
password = oldvalue
EOF

    run route_to_ini "newvalue" "$ini_file" "database" "password"
    assert_success

    run ini_get "$ini_file" "database" "password"
    assert_output "newvalue"
}

@test "route_to_ini: adds key to existing section" {
    local ini_file="$FAKE_REPO/secrets/config.ini"
    mkdir -p "$FAKE_REPO/secrets"

    cat > "$ini_file" <<'EOF'
[database]
host = localhost
EOF

    run route_to_ini "s3cret" "$ini_file" "database" "password"
    assert_success

    run ini_get "$ini_file" "database" "password"
    assert_output "s3cret"
}

@test "route_to_ini: refuses unprotected repo path" {
    local ini_file="$FAKE_REPO/unprotected/config.ini"
    mkdir -p "$FAKE_REPO/unprotected"

    run route_to_ini "s3cret" "$ini_file" "db" "pass"
    assert_failure
    assert_output --partial "BLOCKED"
}

# ── route_to_file ───────────────────────────────────────────────────────────

@test "route_to_file: writes file with correct content" {
    local dest="$FAKE_REPO/secrets/token.txt"

    run route_to_file "my-secret-token" "$dest" "0600"
    assert_success

    [ -f "$dest" ]
    [ "$(cat "$dest")" = "my-secret-token" ]
}

@test "route_to_file: sets correct permissions" {
    local dest="$FAKE_REPO/secrets/key.pem"

    route_to_file "private-key-data" "$dest" "0400"

    local perms
    perms="$(stat -f '%Lp' "$dest" 2>/dev/null || stat -c '%a' "$dest" 2>/dev/null)"
    [ "$perms" = "400" ]
}

@test "route_to_file: allows files outside the repo" {
    local outside_dir
    outside_dir="$(mktemp -d)"
    local dest="${outside_dir}/external-secret.txt"

    run route_to_file "external-data" "$dest" "0600"
    assert_success

    [ -f "$dest" ]
    [ "$(cat "$dest")" = "external-data" ]
    rm -rf "$outside_dir"
}

@test "route_to_file: refuses unprotected repo path" {
    local dest="$FAKE_REPO/scripts/not-encrypted.sh"
    mkdir -p "$FAKE_REPO/scripts"

    run route_to_file "s3cret" "$dest" "0600"
    assert_failure
    assert_output --partial "BLOCKED"
}

# ── route_to_env ────────────────────────────────────────────────────────────

@test "route_to_env: exports variable" {
    route_to_env "my-api-key" "TEST_SECRET_VAR"
    [ "$TEST_SECRET_VAR" = "my-api-key" ]
}

# ── route_secret dispatcher ────────────────────────────────────────────────

@test "route_secret: dispatches to ini" {
    local ini_file="$FAKE_REPO/secrets/dispatch.ini"
    mkdir -p "$FAKE_REPO/secrets"

    run route_secret "val123" "ini" "$ini_file" "sect" "mykey" "" ""
    assert_success

    run ini_get "$ini_file" "sect" "mykey"
    assert_output "val123"
}

@test "route_secret: dispatches to file" {
    local dest="$FAKE_REPO/secrets/dispatched.txt"

    run route_secret "file-content" "file" "$dest" "" "" "" "0600"
    assert_success

    [ -f "$dest" ]
    [ "$(cat "$dest")" = "file-content" ]
}

@test "route_secret: dispatches to env" {
    route_secret "env-val" "env" "" "" "" "DISPATCH_TEST_VAR" ""
    [ "$DISPATCH_TEST_VAR" = "env-val" ]
}

@test "route_secret: rejects unknown dest_type" {
    run route_secret "val" "unknown" "" "" "" "" ""
    assert_failure
    assert_output --partial "Unknown destination type"
}
