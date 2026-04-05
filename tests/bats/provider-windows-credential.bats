#!/usr/bin/env bats

setup() {
    load '../test_helper'
    MOCK_DIR="$(mktemp -d)"

    # Create mock 'powershell.exe'
    cat > "$MOCK_DIR/powershell.exe" <<'MOCK'
#!/usr/bin/env bash
# Parse arguments to find -Action value
action=""
key=""
value=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -Action) action="$2"; shift 2 ;;
        -Key) key="$2"; shift 2 ;;
        -Value) value="$2"; shift 2 ;;
        -Ttl) shift 2 ;;
        *) shift ;;
    esac
done

case "$action" in
    get)
        if [[ "$key" == "unknown-key" ]]; then
            exit 1
        fi
        echo "mock-win-secret"
        exit 0
        ;;
    list)
        echo "machine-setup/test/key"
        echo "other/item"
        exit 0
        ;;
    store)
        exit 0
        ;;
    cache-token)
        exit 0
        ;;
    get-cached-token)
        if [[ "$key" == "expired-token" ]]; then
            exit 1
        fi
        echo "mock-cached-token"
        exit 0
        ;;
    *)
        echo "mock powershell: unhandled action: $action" >&2
        exit 1
        ;;
esac
MOCK
    chmod +x "$MOCK_DIR/powershell.exe"

    # We need to fake a Windows-like environment for provider_available.
    # The provider checks /proc/version for "microsoft" (WSL) or MSYSTEM env var.
    # We'll set MSYSTEM to simulate Git Bash on Windows.
    export MSYSTEM="MINGW64"

    export PATH="$MOCK_DIR:$PATH"

    source "$REPO_ROOT/scripts/lib/common.sh"
    source "$REPO_ROOT/scripts/secrets/providers/windows-credential.sh"
}

teardown() {
    rm -rf "$MOCK_DIR"
    unset MSYSTEM
}

@test "windows-credential: provider_name returns name" {
    run provider_name
    assert_success
    assert_output "Windows Credential Manager"
}

@test "windows-credential: provider_available succeeds in mock Windows env" {
    run provider_available
    assert_success
}

@test "windows-credential: provider_available fails on non-Windows without MSYSTEM" {
    unset MSYSTEM
    # Only skip if we happen to be on actual WSL
    if grep -qi microsoft /proc/version 2>/dev/null; then
        skip "running on WSL"
    fi
    PATH="$MOCK_DIR:$PATH" run provider_available
    assert_failure
}

@test "windows-credential: provider_authenticated always succeeds" {
    run provider_authenticated
    assert_success
}

@test "windows-credential: provider_get_secret retrieves value" {
    run provider_get_secret "machine-setup/test/key"
    assert_success
    assert_output "mock-win-secret"
}

@test "windows-credential: provider_get_secret fails for unknown key" {
    run provider_get_secret "unknown-key"
    assert_failure
}

@test "windows-credential: provider_store_secret succeeds" {
    run provider_store_secret "machine-setup/test/new" "new-value"
    assert_success
}

@test "windows-credential: provider_cache_token succeeds" {
    run provider_cache_token "my-token" "token-value-123" 3600
    assert_success
}

@test "windows-credential: provider_get_cached_token retrieves cached value" {
    run provider_get_cached_token "my-token"
    assert_success
    assert_output "mock-cached-token"
}

@test "windows-credential: provider_get_cached_token fails for expired token" {
    run provider_get_cached_token "expired-token"
    assert_failure
}

@test "windows-credential: provider_list_secrets returns items" {
    run provider_list_secrets ""
    assert_success
    assert_output --partial "machine-setup/test/key"
}
