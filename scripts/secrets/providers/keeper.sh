#!/usr/bin/env bash
# Keeper provider — uses Keeper Commander CLI (`keeper`).
# This file is sourced by the secrets orchestrator; do NOT execute directly.

# shellcheck disable=SC2034
_KEEPER_PROVIDER_LOADED=1

provider_name() {
    echo "Keeper"
}

provider_available() {
    command -v keeper >/dev/null 2>&1
}

provider_authenticated() {
    keeper whoami >/dev/null 2>&1
}

provider_authenticate() {
    keeper login || return 1
}

provider_get_secret() {
    local key="$1"
    keeper get --format=password "$key" 2>/dev/null || return 1
}

provider_list_secrets() {
    local folder="${1:-}"
    local results
    results="$(keeper search "$folder" --format=json 2>/dev/null)" || return 1
    echo "$results" \
        | grep -o '"title":"[^"]*"' \
        | sed 's/"title":"//;s/"//'
}

provider_store_secret() {
    local key="$1"
    local value="$2"
    keeper create --title="$key" --password="$value" >/dev/null 2>&1 || return 1
}
