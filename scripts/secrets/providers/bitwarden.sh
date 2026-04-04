#!/usr/bin/env bash
# Bitwarden provider — uses the `bw` CLI.
# This file is sourced by the secrets orchestrator; do NOT execute directly.

# shellcheck disable=SC2034
_BITWARDEN_PROVIDER_LOADED=1

provider_name() {
    echo "Bitwarden"
}

provider_available() {
    command -v bw >/dev/null 2>&1
}

provider_authenticated() {
    local status
    status="$(bw status 2>/dev/null)" || return 1
    echo "$status" | grep -q '"status":"unlocked"'
}

provider_authenticate() {
    # If not logged in at all, login first
    local status
    status="$(bw status 2>/dev/null)" || true
    if echo "$status" | grep -q '"status":"unauthenticated"'; then
        BW_SESSION="$(bw login --raw)" || return 1
        export BW_SESSION
    elif echo "$status" | grep -q '"status":"locked"'; then
        BW_SESSION="$(bw unlock --raw)" || return 1
        export BW_SESSION
    fi
}

provider_get_secret() {
    local key="$1"
    bw get password "$key" 2>/dev/null || return 1
}

provider_list_secrets() {
    local folder="${1:-}"
    local items
    items="$(bw list items --search "${folder}" 2>/dev/null)" || return 1
    echo "$items" \
        | grep -o '"name":"[^"]*"' \
        | sed 's/"name":"//;s/"//'
}

provider_store_secret() {
    local key="$1"
    local value="$2"

    # Check if item already exists
    local existing
    existing="$(bw get item "$key" 2>/dev/null)" || true

    if [[ -n "$existing" ]]; then
        # Update existing item
        local item_id
        item_id="$(echo "$existing" | grep -o '"id":"[^"]*"' | head -1 | sed 's/"id":"//;s/"//')"
        local encoded
        encoded="$(echo "$existing" \
            | sed "s/\"password\":\"[^\"]*\"/\"password\":\"${value}\"/" \
            | bw encode)"
        bw edit item "$item_id" "$encoded" >/dev/null 2>&1 || return 1
    else
        # Create new login item with the secret as password
        local template
        template="$(bw get template item)" || return 1
        local encoded
        encoded="$(echo "$template" \
            | sed "s/\"name\":\"[^\"]*\"/\"name\":\"${key}\"/" \
            | sed "s/\"password\":null/\"password\":\"${value}\"/" \
            | sed 's/"type":0/"type":1/' \
            | bw encode)"
        bw create item "$encoded" >/dev/null 2>&1 || return 1
    fi
}
