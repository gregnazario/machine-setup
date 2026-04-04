#!/usr/bin/env bash
# Linux Keyring provider — uses `secret-tool` (libsecret / GNOME Keyring).
# This file is sourced by the secrets orchestrator; do NOT execute directly.

# shellcheck disable=SC2034
_LINUX_KEYRING_PROVIDER_LOADED=1

# Application attribute used in all entries
_LK_APP="machine-setup"

provider_name() {
    echo "Linux Keyring"
}

provider_available() {
    command -v secret-tool >/dev/null 2>&1
}

provider_authenticated() {
    # The keyring is available whenever the user session is active
    return 0
}

provider_authenticate() {
    # No-op — the keyring unlocks with the user session
    return 0
}

provider_get_secret() {
    local key="$1"
    secret-tool lookup application "$_LK_APP" key "$key" 2>/dev/null || return 1
}

provider_list_secrets() {
    local folder="${1:-}"
    secret-tool search --all application "$_LK_APP" 2>/dev/null \
        | grep "attribute.key" \
        | sed 's/.*= //' \
        | if [[ -n "$folder" ]]; then grep "^${folder}"; else cat; fi
}

provider_store_secret() {
    local key="$1"
    local value="$2"
    echo -n "$value" \
        | secret-tool store --label="machine-setup: $key" \
            application "$_LK_APP" key "$key" 2>/dev/null || return 1
}

###############################################################################
# Keychain cache functions
###############################################################################

provider_cache_token() {
    local name="$1"
    local value="$2"
    local ttl_seconds="${3:-3600}"
    local cache_key="cache-${name}"

    # Store the value
    echo -n "$value" \
        | secret-tool store --label="machine-setup cache: $name" \
            application "$_LK_APP" key "$cache_key" 2>/dev/null || return 1

    # Store the expiry timestamp
    local expiry
    expiry="$(( $(date +%s) + ttl_seconds ))"
    echo -n "$expiry" \
        | secret-tool store --label="machine-setup cache-ts: $name" \
            application "$_LK_APP" key "${cache_key}-ts" 2>/dev/null || return 1
}

provider_get_cached_token() {
    local name="$1"
    local cache_key="cache-${name}"

    # Check expiry first
    local expiry
    expiry="$(secret-tool lookup application "$_LK_APP" key "${cache_key}-ts" 2>/dev/null)" || return 1
    local now
    now="$(date +%s)"
    if [[ "$now" -ge "$expiry" ]]; then
        # Token has expired
        return 1
    fi

    secret-tool lookup application "$_LK_APP" key "$cache_key" 2>/dev/null || return 1
}
