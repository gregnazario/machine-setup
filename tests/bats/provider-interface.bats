#!/usr/bin/env bats

setup() {
    load '../test_helper'

    PROVIDERS_DIR="$REPO_ROOT/scripts/secrets/providers"
}

# ---------------------------------------------------------------------------
# Interface completeness checks — every .sh provider must define all 7 funcs
# ---------------------------------------------------------------------------

@test "all providers implement required interface functions" {
    local required_funcs=(
        provider_name
        provider_available
        provider_authenticated
        provider_authenticate
        provider_get_secret
        provider_list_secrets
        provider_store_secret
    )
    local providers=("1password" "bitwarden" "keeper" "apple-keychain" "linux-keyring" "windows-credential")

    for p in "${providers[@]}"; do
        local file="$PROVIDERS_DIR/${p}.sh"
        assert [ -f "$file" ]
        for fn in "${required_funcs[@]}"; do
            run grep -q "^${fn}()" "$file"
            assert_success
        done
    done
}

# ---------------------------------------------------------------------------
# Keychain providers must additionally implement cache functions
# ---------------------------------------------------------------------------

@test "keychain providers implement cache functions" {
    local cache_funcs=(
        provider_cache_token
        provider_get_cached_token
    )
    local keychain_providers=("apple-keychain" "linux-keyring" "windows-credential")

    for p in "${keychain_providers[@]}"; do
        local file="$PROVIDERS_DIR/${p}.sh"
        for fn in "${cache_funcs[@]}"; do
            run grep -q "^${fn}()" "$file"
            assert_success
        done
    done
}

# ---------------------------------------------------------------------------
# PowerShell script exists and accepts Action parameter
# ---------------------------------------------------------------------------

@test "windows-credential.ps1 exists and accepts Action parameter" {
    local ps1="$PROVIDERS_DIR/windows-credential.ps1"
    assert [ -f "$ps1" ]
    run grep -q '\[Parameter(Mandatory)\]' "$ps1"
    assert_success
    run grep -q '\[string\]\$Action' "$ps1"
    assert_success
}

# ---------------------------------------------------------------------------
# Each provider_name returns a non-empty string
# ---------------------------------------------------------------------------

@test "1password provider_name returns non-empty string" {
    source "$PROVIDERS_DIR/1password.sh"
    run provider_name
    assert_success
    assert [ -n "$output" ]
}

@test "bitwarden provider_name returns non-empty string" {
    source "$PROVIDERS_DIR/bitwarden.sh"
    run provider_name
    assert_success
    assert [ -n "$output" ]
}

@test "keeper provider_name returns non-empty string" {
    source "$PROVIDERS_DIR/keeper.sh"
    run provider_name
    assert_success
    assert [ -n "$output" ]
}

@test "apple-keychain provider_name returns non-empty string" {
    source "$PROVIDERS_DIR/apple-keychain.sh"
    run provider_name
    assert_success
    assert [ -n "$output" ]
}

@test "linux-keyring provider_name returns non-empty string" {
    source "$PROVIDERS_DIR/linux-keyring.sh"
    run provider_name
    assert_success
    assert [ -n "$output" ]
}

@test "windows-credential provider_name returns non-empty string" {
    source "$PROVIDERS_DIR/windows-credential.sh"
    run provider_name
    assert_success
    assert [ -n "$output" ]
}

# ---------------------------------------------------------------------------
# provider_available returns 1 when CLI is not on PATH
# ---------------------------------------------------------------------------

@test "1password provider_available returns 1 when op not on PATH" {
    source "$PROVIDERS_DIR/1password.sh"
    PATH="/nonexistent" run provider_available
    assert_failure
}

@test "bitwarden provider_available returns 1 when bw not on PATH" {
    source "$PROVIDERS_DIR/bitwarden.sh"
    PATH="/nonexistent" run provider_available
    assert_failure
}

@test "keeper provider_available returns 1 when keeper not on PATH" {
    source "$PROVIDERS_DIR/keeper.sh"
    PATH="/nonexistent" run provider_available
    assert_failure
}

@test "linux-keyring provider_available returns 1 when secret-tool not on PATH" {
    source "$PROVIDERS_DIR/linux-keyring.sh"
    PATH="/nonexistent" run provider_available
    assert_failure
}

@test "windows-credential provider_available returns 1 on non-Windows" {
    # Unless we are actually on WSL/Windows, this should fail
    if grep -qi microsoft /proc/version 2>/dev/null; then
        skip "running on WSL"
    fi
    if [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]]; then
        skip "running on native Windows"
    fi
    source "$PROVIDERS_DIR/windows-credential.sh"
    run provider_available
    assert_failure
}

# ---------------------------------------------------------------------------
# Password-manager providers (not keychains) must NOT define cache functions
# ---------------------------------------------------------------------------

@test "password manager providers do not define cache functions" {
    local pm_providers=("1password" "bitwarden" "keeper")
    for p in "${pm_providers[@]}"; do
        local file="$PROVIDERS_DIR/${p}.sh"
        run grep -c "^provider_cache_token()" "$file"
        assert_output "0"
        run grep -c "^provider_get_cached_token()" "$file"
        assert_output "0"
    done
}
