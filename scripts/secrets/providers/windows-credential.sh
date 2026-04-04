#!/usr/bin/env bash
# Windows Credential provider — bash wrapper that delegates to PowerShell.
# Works on both native Windows (Git Bash / MSYS2) and WSL.
# This file is sourced by the secrets orchestrator; do NOT execute directly.

# shellcheck disable=SC2034
_WINDOWS_CREDENTIAL_PROVIDER_LOADED=1

# Resolve the directory containing this script
_WC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_WC_PS1_SCRIPT="${_WC_DIR}/windows-credential.ps1"

###############################################################################
# _wc_powershell <action> [key] [value] [ttl]
#
# Locate the correct PowerShell binary and invoke the .ps1 script.
###############################################################################
_wc_powershell() {
    local action="$1"
    local key="${2:-}"
    local value="${3:-}"
    local ttl="${4:-3600}"

    local ps_exe=""
    local ps1_path="$_WC_PS1_SCRIPT"

    # Detect WSL vs native Windows
    if grep -qi microsoft /proc/version 2>/dev/null; then
        # WSL — call Windows PowerShell via interop
        ps_exe="powershell.exe"
        # Convert Linux path to Windows path for WSL interop
        ps1_path="$(wslpath -w "$_WC_PS1_SCRIPT" 2>/dev/null || echo "$_WC_PS1_SCRIPT")"
    elif [[ -n "${MSYSTEM:-}" ]] || [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]]; then
        # Native Windows (Git Bash / MSYS2)
        ps_exe="powershell.exe"
    else
        # Not a Windows environment
        return 1
    fi

    local -a args=("-NoProfile" "-ExecutionPolicy" "Bypass" "-File" "$ps1_path"
                   "-Action" "$action")
    [[ -n "$key" ]]   && args+=("-Key" "$key")
    [[ -n "$value" ]] && args+=("-Value" "$value")
    [[ -n "$ttl" ]]   && args+=("-Ttl" "$ttl")

    "$ps_exe" "${args[@]}" 2>/dev/null
}

provider_name() {
    echo "Windows Credential Manager"
}

provider_available() {
    # Check that we are on a Windows-like platform and powershell is reachable
    if grep -qi microsoft /proc/version 2>/dev/null; then
        command -v powershell.exe >/dev/null 2>&1
    elif [[ -n "${MSYSTEM:-}" ]] || [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]]; then
        command -v powershell.exe >/dev/null 2>&1
    else
        return 1
    fi
}

provider_authenticated() {
    # Credential store is always available when the user is logged in
    return 0
}

provider_authenticate() {
    # No-op — credentials are tied to the Windows login session
    return 0
}

provider_get_secret() {
    local key="$1"
    local result
    result="$(_wc_powershell "get" "$key")" || return 1
    [[ -n "$result" ]] && echo "$result" || return 1
}

provider_list_secrets() {
    local folder="${1:-}"
    _wc_powershell "list" "$folder" || return 1
}

provider_store_secret() {
    local key="$1"
    local value="$2"
    _wc_powershell "store" "$key" "$value" || return 1
}

###############################################################################
# Keychain cache functions
###############################################################################

provider_cache_token() {
    local name="$1"
    local value="$2"
    local ttl_seconds="${3:-3600}"
    _wc_powershell "cache-token" "$name" "$value" "$ttl_seconds" || return 1
}

provider_get_cached_token() {
    local name="$1"
    _wc_powershell "get-cached-token" "$name" || return 1
}
