<#
.SYNOPSIS
    Windows Credential Manager provider for machine-setup secrets.

.DESCRIPTION
    Uses DPAPI (Data Protection API) to store encrypted secrets under
    $env:APPDATA\machine-setup\secrets\.  This is user-scoped encryption:
    only the same Windows user account can decrypt the data.

.PARAMETER Action
    One of: available, get, store, list, cache-token, get-cached-token

.PARAMETER Key
    The secret key / name.

.PARAMETER Value
    The secret value (for store / cache-token).

.PARAMETER Ttl
    Time-to-live in seconds for cached tokens (default 3600).
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet("available", "get", "store", "list", "cache-token", "get-cached-token")]
    [string]$Action,

    [string]$Key = "",
    [string]$Value = "",
    [int]$Ttl = 3600
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Security

$SecretsDir = Join-Path $env:APPDATA "machine-setup" "secrets"

function Ensure-SecretsDir {
    if (-not (Test-Path $SecretsDir)) {
        New-Item -ItemType Directory -Path $SecretsDir -Force | Out-Null
    }
}

function Get-SecretPath([string]$name) {
    # Use base64-encoded filenames to avoid lossy character translation
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($name)) -replace '[/+=]', '_'
    return Join-Path $SecretsDir "$encoded.dat"
}

function Get-OriginalName([string]$fileName) {
    $encoded = [IO.Path]::GetFileNameWithoutExtension($fileName) -replace '_', '+'
    # Pad base64 if needed
    $mod = $encoded.Length % 4
    if ($mod -ne 0) { $encoded += '=' * (4 - $mod) }
    return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
}

function Protect-String([string]$plaintext) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($plaintext)
    $encrypted = [System.Security.Cryptography.ProtectedData]::Protect(
        $bytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    return $encrypted
}

function Unprotect-File([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    $encrypted = [System.IO.File]::ReadAllBytes($path)
    $decrypted = [System.Security.Cryptography.ProtectedData]::Unprotect(
        $encrypted, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    return [System.Text.Encoding]::UTF8.GetString($decrypted)
}

switch ($Action) {
    "available" {
        # DPAPI is always available on Windows
        exit 0
    }

    "get" {
        if (-not $Key) { Write-Error "Key is required"; exit 1 }
        $path = Get-SecretPath $Key
        $value = Unprotect-File $path
        if ($null -eq $value) { exit 1 }
        Write-Output $value
    }

    "store" {
        if (-not $Key) { Write-Error "Key is required"; exit 1 }
        Ensure-SecretsDir
        $path = Get-SecretPath $Key
        $encrypted = Protect-String $Value
        [System.IO.File]::WriteAllBytes($path, $encrypted)
    }

    "list" {
        Ensure-SecretsDir
        $prefix = if ($Key) { $Key } else { "" }
        Get-ChildItem -Path $SecretsDir -Filter "*.dat" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^cache-' } |
            ForEach-Object { Get-OriginalName $_.Name } |
            Where-Object { $_ -like "$prefix*" } |
            ForEach-Object { Write-Output $_ }
    }

    "cache-token" {
        if (-not $Key) { Write-Error "Key is required"; exit 1 }
        Ensure-SecretsDir
        # Store the value
        $cacheName = "cache-$Key"
        $path = Get-SecretPath $cacheName
        $encrypted = Protect-String $Value
        [System.IO.File]::WriteAllBytes($path, $encrypted)
        # Store the expiry timestamp
        $expiry = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + $Ttl
        $tsPath = Get-SecretPath "$cacheName-ts"
        $tsEncrypted = Protect-String "$expiry"
        [System.IO.File]::WriteAllBytes($tsPath, $tsEncrypted)
    }

    "get-cached-token" {
        if (-not $Key) { Write-Error "Key is required"; exit 1 }
        $cacheName = "cache-$Key"
        # Check expiry
        $tsPath = Get-SecretPath "$cacheName-ts"
        $expiryStr = Unprotect-File $tsPath
        if ($null -eq $expiryStr) { exit 1 }
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        if ($now -ge [long]$expiryStr) {
            # Expired — clean up
            Remove-Item (Get-SecretPath $cacheName) -ErrorAction SilentlyContinue
            Remove-Item $tsPath -ErrorAction SilentlyContinue
            exit 1
        }
        $value = Unprotect-File (Get-SecretPath $cacheName)
        if ($null -eq $value) { exit 1 }
        Write-Output $value
    }
}
