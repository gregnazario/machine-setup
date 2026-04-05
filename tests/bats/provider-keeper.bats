#!/usr/bin/env bats

setup() {
    load '../test_helper'
    MOCK_DIR="$(mktemp -d)"

    # Create mock 'keeper' CLI
    cat > "$MOCK_DIR/keeper" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    whoami)
        echo "user@example.com"
        exit 0
        ;;
    get)
        # keeper get --format=password <key>
        if [[ "$*" == *"unknown-key"* ]]; then
            echo "Error: record not found" >&2
            exit 1
        fi
        echo "mock-keeper-secret"
        exit 0
        ;;
    search)
        echo '{"title":"machine-setup/test/key"}'
        exit 0
        ;;
    create)
        echo "Record created"
        exit 0
        ;;
    login)
        exit 0
        ;;
    *)
        echo "mock keeper: unhandled: $*" >&2
        exit 1
        ;;
esac
MOCK
    chmod +x "$MOCK_DIR/keeper"
    export PATH="$MOCK_DIR:$PATH"

    source "$REPO_ROOT/scripts/lib/common.sh"
    source "$REPO_ROOT/scripts/secrets/providers/keeper.sh"
}

teardown() {
    rm -rf "$MOCK_DIR"
}

@test "keeper: provider_name returns name" {
    run provider_name
    assert_success
    assert_output "Keeper"
}

@test "keeper: provider_available succeeds with mock keeper" {
    run provider_available
    assert_success
}

@test "keeper: provider_available fails when keeper not on PATH" {
    PATH="/nonexistent" run provider_available
    assert_failure
}

@test "keeper: provider_authenticated succeeds with mock" {
    run provider_authenticated
    assert_success
}

@test "keeper: provider_get_secret retrieves value" {
    run provider_get_secret "machine-setup/test/key"
    assert_success
    assert_output "mock-keeper-secret"
}

@test "keeper: provider_get_secret fails for unknown key" {
    run provider_get_secret "unknown-key"
    assert_failure
}

@test "keeper: provider_store_secret succeeds" {
    run provider_store_secret "machine-setup/test/new" "new-value"
    assert_success
}

@test "keeper: provider_list_secrets returns items" {
    run provider_list_secrets "machine-setup"
    assert_success
    assert_output --partial "machine-setup/test/key"
}
