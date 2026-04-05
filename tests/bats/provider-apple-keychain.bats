#!/usr/bin/env bats

setup() {
    load '../test_helper'
    MOCK_DIR="$(mktemp -d)"

    # Mock uname to return Darwin for platform check
    cat > "$MOCK_DIR/uname" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "-s" ]]; then
    echo "Darwin"
elif [[ -z "$1" ]]; then
    echo "Darwin"
else
    /usr/bin/uname "$@"
fi
MOCK
    chmod +x "$MOCK_DIR/uname"

    # Create mock 'security' command
    cat > "$MOCK_DIR/security" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    find-generic-password)
        # Parse -s (service) and -w (output password) flags
        local service=""
        local want_password=false
        shift
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -s) service="$2"; shift 2 ;;
                -a) shift 2 ;;  # skip account
                -w) want_password=true; shift ;;
                *) shift ;;
            esac
        done
        if [[ "$service" == *"unknown"* ]]; then
            echo "security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain." >&2
            exit 44
        fi
        # Return a cached token expiry far in the future for cache tests
        if [[ "$service" == *"-ts" ]]; then
            echo "9999999999"
            exit 0
        fi
        if $want_password; then
            echo "mock-keychain-value"
        fi
        exit 0
        ;;
    add-generic-password)
        exit 0
        ;;
    delete-generic-password)
        exit 0
        ;;
    dump-keychain)
        cat <<'DUMP'
class: "genp"
    "svce"<blob>="machine-setup/test/key"
    "acct"<blob>="machine-setup"
class: "genp"
    "svce"<blob>="machine-setup/other/key"
    "acct"<blob>="machine-setup"
DUMP
        exit 0
        ;;
    *)
        echo "mock security: unhandled: $*" >&2
        exit 1
        ;;
esac
MOCK
    chmod +x "$MOCK_DIR/security"
    export PATH="$MOCK_DIR:$PATH"

    source "$REPO_ROOT/scripts/lib/common.sh"
    source "$REPO_ROOT/scripts/secrets/providers/apple-keychain.sh"
}

teardown() {
    rm -rf "$MOCK_DIR"
}

@test "apple-keychain: provider_name returns name" {
    run provider_name
    assert_success
    assert_output "Apple Keychain"
}

@test "apple-keychain: provider_available succeeds with mock security and Darwin" {
    run provider_available
    assert_success
}

@test "apple-keychain: provider_available fails when security not on PATH" {
    PATH="/nonexistent" run provider_available
    assert_failure
}

@test "apple-keychain: provider_authenticated always succeeds" {
    run provider_authenticated
    assert_success
}

@test "apple-keychain: provider_get_secret retrieves value" {
    run provider_get_secret "machine-setup/test/key"
    assert_success
    assert_output "mock-keychain-value"
}

@test "apple-keychain: provider_get_secret fails for unknown key" {
    run provider_get_secret "unknown-key"
    assert_failure
}

@test "apple-keychain: provider_store_secret succeeds" {
    run provider_store_secret "machine-setup/test/new" "new-value"
    assert_success
}

@test "apple-keychain: provider_cache_token succeeds" {
    run provider_cache_token "my-token" "token-value-123" 3600
    assert_success
}

@test "apple-keychain: provider_get_cached_token retrieves cached value" {
    run provider_get_cached_token "my-token"
    assert_success
    assert_output "mock-keychain-value"
}

@test "apple-keychain: provider_get_cached_token fails for expired token" {
    # Override mock to return an expired timestamp
    cat > "$MOCK_DIR/security" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    find-generic-password)
        local service=""
        shift
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -s) service="$2"; shift 2 ;;
                -a) shift 2 ;;
                -w) shift ;;
                *) shift ;;
            esac
        done
        # Return expired timestamp
        if [[ "$service" == *"-ts" ]]; then
            echo "1000000000"
            exit 0
        fi
        echo "stale-value"
        exit 0
        ;;
    delete-generic-password)
        exit 0
        ;;
    *)
        exit 1
        ;;
esac
MOCK
    chmod +x "$MOCK_DIR/security"

    run provider_get_cached_token "my-token"
    assert_failure
}

@test "apple-keychain: provider_list_secrets returns items" {
    run provider_list_secrets
    assert_success
    assert_output --partial "machine-setup/test/key"
}
