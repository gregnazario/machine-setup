#!/usr/bin/env bats

setup() {
    load '../test_helper'
    MOCK_DIR="$(mktemp -d)"

    # Create mock 'bw' CLI
    cat > "$MOCK_DIR/bw" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    status)
        echo '{"status":"unlocked"}'
        exit 0
        ;;
    get)
        case "$2" in
            password)
                if [[ "${3:-}" == "unknown-key" ]]; then
                    echo "Not found." >&2
                    exit 1
                fi
                echo "mock-bw-secret"
                exit 0
                ;;
            item)
                # For store_secret existence check — pretend not found
                exit 1
                ;;
            template)
                echo '{"name":"","type":1,"login":{"password":""}}'
                exit 0
                ;;
            *)
                echo "mock bw get: unhandled: $*" >&2
                exit 1
                ;;
        esac
        ;;
    list)
        echo '[{"name":"machine-setup/test/key"},{"name":"other/item"}]'
        exit 0
        ;;
    encode)
        # Just pass through stdin as base64-ish (not real, but enough for mock)
        cat
        exit 0
        ;;
    create)
        echo '{"id":"new-item-123"}'
        exit 0
        ;;
    edit)
        exit 0
        ;;
    *)
        echo "mock bw: unhandled: $*" >&2
        exit 1
        ;;
esac
MOCK
    chmod +x "$MOCK_DIR/bw"

    # Create mock python3 for store_secret JSON manipulation
    cat > "$MOCK_DIR/python3" <<'MOCK'
#!/usr/bin/env bash
# Simple pass-through — just echo a valid JSON template
echo '{"name":"test","type":1,"login":{"password":"value"}}'
MOCK
    chmod +x "$MOCK_DIR/python3"

    export PATH="$MOCK_DIR:$PATH"

    source "$REPO_ROOT/scripts/lib/common.sh"
    source "$REPO_ROOT/scripts/secrets/providers/bitwarden.sh"
}

teardown() {
    rm -rf "$MOCK_DIR"
}

@test "bitwarden: provider_name returns name" {
    run provider_name
    assert_success
    assert_output "Bitwarden"
}

@test "bitwarden: provider_available succeeds with mock bw" {
    run provider_available
    assert_success
}

@test "bitwarden: provider_available fails when bw not on PATH" {
    PATH="/nonexistent" run provider_available
    assert_failure
}

@test "bitwarden: provider_authenticated succeeds with unlocked status" {
    run provider_authenticated
    assert_success
}

@test "bitwarden: provider_authenticated fails when locked" {
    cat > "$MOCK_DIR/bw" <<'MOCK'
#!/usr/bin/env bash
echo '{"status":"locked"}'
MOCK
    chmod +x "$MOCK_DIR/bw"

    run provider_authenticated
    assert_failure
}

@test "bitwarden: provider_get_secret retrieves value" {
    run provider_get_secret "machine-setup/test/key"
    assert_success
    assert_output "mock-bw-secret"
}

@test "bitwarden: provider_get_secret fails for unknown key" {
    run provider_get_secret "unknown-key"
    assert_failure
}

@test "bitwarden: provider_store_secret succeeds" {
    run provider_store_secret "machine-setup/test/new" "new-value"
    assert_success
}

@test "bitwarden: provider_list_secrets returns items" {
    run provider_list_secrets ""
    assert_success
    assert_output --partial "machine-setup/test/key"
}
