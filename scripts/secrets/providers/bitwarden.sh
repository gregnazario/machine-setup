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
        local item_id
        item_id="$(printf '%s' "$existing" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')" || return 1
        local encoded
        encoded="$(printf '%s' "$existing" | python3 -c '
import json,sys
data = json.load(sys.stdin)
data["name"] = sys.argv[1]
data.setdefault("login",{})["password"] = sys.argv[2]
print(json.dumps(data))
' "$key" "$value" | bw encode)" || return 1
        bw edit item "$item_id" "$encoded" >/dev/null 2>&1 || return 1
    else
        # Create new login item with the secret as password
        local template
        template="$(bw get template item)" || return 1
        local encoded
        encoded="$(printf '%s' "$template" | python3 -c '
import json,sys
data = json.load(sys.stdin)
data["name"] = sys.argv[1]
data["type"] = 1
data.setdefault("login",{})["password"] = sys.argv[2]
print(json.dumps(data))
' "$key" "$value" | bw encode)" || return 1
        bw create item "$encoded" >/dev/null 2>&1 || return 1
    fi
}
