#!/usr/bin/env bats

setup() {
    load '../test_helper'
    MOCK_DIR="$(mktemp -d)"

    # Create mock 'secret-tool'
    cat > "$MOCK_DIR/secret-tool" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    lookup)
        # secret-tool lookup application machine-setup key <keyname>
        local key=""
        shift
        while [[ $# -gt 0 ]]; do
            case "$1" in
                key) key="$2"; shift 2 ;;
                *) shift 2 ;;
            esac
        done
        if [[ "$key" == *"unknown"* ]]; then
            exit 1
        fi
        # For cache timestamp checks, return a far-future timestamp
        if [[ "$key" == *"-ts" ]]; then
            echo -n "9999999999"
            exit 0
        fi
        echo -n "mock-keyring-secret"
        exit 0
        ;;
    search)
        cat <<'SEARCH'
[/org/freedesktop/secrets/collection/login/1]
label = machine-setup: test/key
attribute.application = machine-setup
attribute.key = machine-setup/test/key
[/org/freedesktop/secrets/collection/login/2]
label = machine-setup: other
attribute.application = machine-setup
attribute.key = other/item
SEARCH
        exit 0
        ;;
    store)
        exit 0
        ;;
    *)
        echo "mock secret-tool: unhandled: $*" >&2
        exit 1
        ;;
esac
MOCK
    chmod +x "$MOCK_DIR/secret-tool"
    export PATH="$MOCK_DIR:$PATH"

    source "$REPO_ROOT/scripts/lib/common.sh"
    source "$REPO_ROOT/scripts/secrets/providers/linux-keyring.sh"
}

teardown() {
    rm -rf "$MOCK_DIR"
}

@test "linux-keyring: provider_name returns name" {
    run provider_name
    assert_success
    assert_output "Linux Keyring"
}

@test "linux-keyring: provider_available succeeds with mock secret-tool" {
    run provider_available
    assert_success
}

@test "linux-keyring: provider_available fails when secret-tool not on PATH" {
    PATH="/nonexistent" run provider_available
    assert_failure
}

@test "linux-keyring: provider_authenticated always succeeds" {
    run provider_authenticated
    assert_success
}

@test "linux-keyring: provider_get_secret retrieves value" {
    run provider_get_secret "machine-setup/test/key"
    assert_success
    assert_output "mock-keyring-secret"
}

@test "linux-keyring: provider_get_secret fails for unknown key" {
    run provider_get_secret "unknown-key"
    assert_failure
}

@test "linux-keyring: provider_store_secret succeeds" {
    run provider_store_secret "machine-setup/test/new" "new-value"
    assert_success
}

@test "linux-keyring: provider_cache_token succeeds" {
    run provider_cache_token "my-token" "token-value-123" 3600
    assert_success
}

@test "linux-keyring: provider_get_cached_token retrieves cached value" {
    run provider_get_cached_token "my-token"
    assert_success
    assert_output "mock-keyring-secret"
}

@test "linux-keyring: provider_get_cached_token fails for expired token" {
    # Override mock to return an expired timestamp
    cat > "$MOCK_DIR/secret-tool" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    lookup)
        local key=""
        shift
        while [[ $# -gt 0 ]]; do
            case "$1" in
                key) key="$2"; shift 2 ;;
                *) shift 2 ;;
            esac
        done
        # Return expired timestamp
        if [[ "$key" == *"-ts" ]]; then
            echo -n "1000000000"
            exit 0
        fi
        echo -n "stale-value"
        exit 0
        ;;
    *)
        exit 1
        ;;
esac
MOCK
    chmod +x "$MOCK_DIR/secret-tool"

    run provider_get_cached_token "my-token"
    assert_failure
}

@test "linux-keyring: provider_list_secrets returns items" {
    run provider_list_secrets
    assert_success
    assert_output --partial "machine-setup/test/key"
}
