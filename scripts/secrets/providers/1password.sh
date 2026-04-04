#!/usr/bin/env bash
# 1Password provider — uses the `op` CLI.
# This file is sourced by the secrets orchestrator; do NOT execute directly.

# shellcheck disable=SC2034
_1PASSWORD_PROVIDER_LOADED=1

# Vault override: set OP_VAULT in env or secrets.conf [provider] vault
_OP_VAULT="${OP_VAULT:-Personal}"

provider_name() {
    echo "1Password"
}

provider_available() {
    command -v op >/dev/null 2>&1
}

provider_authenticated() {
    op whoami >/dev/null 2>&1
}

provider_authenticate() {
    eval "$(op signin)" || return 1
}

provider_get_secret() {
    local key="$1"
    op item get "$key" --fields password --vault "$_OP_VAULT" 2>/dev/null || return 1
}

provider_list_secrets() {
    local folder="${1:-}"
    local items
    items="$(op item list --vault "$_OP_VAULT" --format=json 2>/dev/null)" || return 1
    echo "$items" \
        | grep -o '"title":"[^"]*"' \
        | sed 's/"title":"//;s/"//' \
        | if [[ -n "$folder" ]]; then grep "^${folder}"; else cat; fi
}

provider_store_secret() {
    local key="$1"
    local value="$2"

    # Try to update existing item first; create if it does not exist
    if op item get "$key" --vault "$_OP_VAULT" >/dev/null 2>&1; then
        op item edit "$key" --vault "$_OP_VAULT" "password=${value}" >/dev/null 2>&1 || return 1
    else
        op item create --category=password --title="$key" \
            --vault "$_OP_VAULT" "password=${value}" >/dev/null 2>&1 || return 1
    fi
}
