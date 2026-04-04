#!/usr/bin/env bash
# Apple Keychain provider — uses the macOS `security` command.
# This file is sourced by the secrets orchestrator; do NOT execute directly.

# shellcheck disable=SC2034
_APPLE_KEYCHAIN_PROVIDER_LOADED=1

# Account label used for all machine-setup entries
_AK_ACCOUNT="machine-setup"

provider_name() {
    echo "Apple Keychain"
}

provider_available() {
    [[ "$(uname)" == "Darwin" ]] && command -v security >/dev/null 2>&1
}

provider_authenticated() {
    # Keychain is available whenever the user is logged in
    return 0
}

provider_authenticate() {
    # No-op on macOS
    return 0
}

provider_get_secret() {
    local key="$1"
    security find-generic-password -s "$key" -a "$_AK_ACCOUNT" -w 2>/dev/null || return 1
}

provider_list_secrets() {
    local folder="${1:-}"
    security dump-keychain 2>/dev/null \
        | grep -A4 'class: "genp"' \
        | grep "svce" \
        | sed 's/.*="//;s/".*//' \
        | sort -u \
        | if [[ -n "$folder" ]]; then grep "^${folder}"; else cat; fi
}

provider_store_secret() {
    local key="$1"
    local value="$2"
    # -U updates if the entry already exists
    security add-generic-password -U -s "$key" -a "$_AK_ACCOUNT" -w "$value" 2>/dev/null || return 1
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
    security add-generic-password -U -s "$cache_key" -a "$_AK_ACCOUNT" -w "$value" 2>/dev/null || return 1

    # Store the expiry timestamp
    local expiry
    expiry="$(( $(date +%s) + ttl_seconds ))"
    security add-generic-password -U -s "${cache_key}-ts" -a "$_AK_ACCOUNT" -w "$expiry" 2>/dev/null || return 1
}

provider_get_cached_token() {
    local name="$1"
    local cache_key="cache-${name}"

    # Check expiry first
    local expiry
    expiry="$(security find-generic-password -s "${cache_key}-ts" -a "$_AK_ACCOUNT" -w 2>/dev/null)" || return 1
    local now
    now="$(date +%s)"
    if [[ "$now" -ge "$expiry" ]]; then
        # Token has expired — clean up
        security delete-generic-password -s "$cache_key" -a "$_AK_ACCOUNT" >/dev/null 2>&1
        security delete-generic-password -s "${cache_key}-ts" -a "$_AK_ACCOUNT" >/dev/null 2>&1
        return 1
    fi

    security find-generic-password -s "$cache_key" -a "$_AK_ACCOUNT" -w 2>/dev/null || return 1
}
