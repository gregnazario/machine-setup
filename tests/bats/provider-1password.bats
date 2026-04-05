#!/usr/bin/env bats

setup() {
    load '../test_helper'
    MOCK_DIR="$(mktemp -d)"

    # Create mock 'op' CLI
    cat > "$MOCK_DIR/op" <<'MOCK'
#!/usr/bin/env bash
case "$*" in
    "whoami")
        echo '{"email":"test@example.com"}'
        exit 0
        ;;
    *"item get"*"--fields password"*)
        echo "mock-secret-value"
        exit 0
        ;;
    *"item get"*"unknown-key"*)
        exit 1
        ;;
    *"item get"*)
        # For store_secret existence check — pretend item does not exist
        exit 1
        ;;
    *"item list"*)
        echo '[{"title":"machine-setup/test/key"},{"title":"other/item"}]'
        exit 0
        ;;
    *"item create"*)
        echo '{"id":"abc123"}'
        exit 0
        ;;
    *"item edit"*)
        exit 0
        ;;
    *)
        echo "mock: unhandled: $*" >&2
        exit 1
        ;;
esac
MOCK
    chmod +x "$MOCK_DIR/op"
    export PATH="$MOCK_DIR:$PATH"

    source "$REPO_ROOT/scripts/lib/common.sh"
    source "$REPO_ROOT/scripts/secrets/providers/1password.sh"
}

teardown() {
    rm -rf "$MOCK_DIR"
}

@test "1password: provider_name returns name" {
    run provider_name
    assert_success
    assert_output "1Password"
}

@test "1password: provider_available succeeds with mock op" {
    run provider_available
    assert_success
}

@test "1password: provider_available fails when op not on PATH" {
    PATH="/nonexistent" run provider_available
    assert_failure
}

@test "1password: provider_authenticated succeeds with mock" {
    run provider_authenticated
    assert_success
}

@test "1password: provider_get_secret retrieves value" {
    run provider_get_secret "machine-setup/test/key"
    assert_success
    assert_output "mock-secret-value"
}

@test "1password: provider_get_secret fails for unknown key" {
    # Override mock to fail for this specific key
    cat > "$MOCK_DIR/op" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$MOCK_DIR/op"

    run provider_get_secret "nonexistent/key"
    assert_failure
}

@test "1password: provider_store_secret succeeds (creates new item)" {
    run provider_store_secret "machine-setup/test/new" "new-value"
    assert_success
}

@test "1password: provider_list_secrets returns items" {
    run provider_list_secrets
    assert_success
    assert_output --partial "machine-setup/test/key"
}
