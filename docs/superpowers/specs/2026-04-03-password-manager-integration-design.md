# Password Manager Integration - Design Spec

## Goal

Integrate password managers (1Password, Bitwarden, Keeper) and OS keychains (Apple Keychain, Windows Credential Manager, Linux libsecret) as the source of truth for all secrets in machine-setup. Secrets are pulled from the provider, routed to encrypted destinations (git-crypt files, INI injection, environment variables), and never stored unencrypted on disk. The provider system is extensible — adding a new password manager requires one file implementing a standard interface.

## Architecture

### Two-Tier Provider System

**Tier 1 — Password Managers** (full-featured, structured storage):
- 1Password (`op` CLI)
- Bitwarden (`bw` CLI)
- Keeper (`keeper` CLI)
- Extensible: add a new `.sh` file in `providers/`

**Tier 2 — OS Keychains** (simple key-value stores):
- Apple Keychain (`security` command)
- Windows Credential Manager (PowerShell `CredentialManager` module / `cmdkey.exe`)
- Linux keyring (`secret-tool` from libsecret)

Keychains serve two roles:
1. **Standalone provider** — for users who don't want a full password manager, store secrets directly in the OS keychain
2. **Caching layer** — cache password manager session tokens so users don't re-authenticate on every `--secrets` call

### Provider Interface

Each provider in `scripts/secrets/providers/<name>.sh` implements these functions:

```bash
provider_name()              # Return the provider's display name
provider_available()         # Exit 0 if CLI/API is accessible, 1 otherwise
provider_authenticated()     # Exit 0 if session is active, 1 otherwise
provider_authenticate()      # Log in (may prompt user interactively)
provider_get_secret(key)     # Print secret value to stdout; exit 1 if not found
provider_list_secrets(folder)# Print one key per line in the given namespace
provider_store_secret(key, value) # Write a secret; exit 1 on failure
```

Keychain providers additionally implement:

```bash
provider_cache_token(name, value, ttl_seconds) # Store a session token with expiry
provider_get_cached_token(name)                 # Retrieve a cached token; exit 1 if expired/missing
```

All functions follow these contracts:
- Secret values are printed to stdout with no trailing newline decoration
- Errors go to stderr
- Exit codes: 0 = success, 1 = failure
- Binary secrets (SSH keys, GPG keys) are base64-encoded in the provider and decoded on retrieval

### Windows Support — Bilingual Providers

Windows has two execution contexts that need different implementations:

**WSL**: The `.sh` provider calls `powershell.exe` via interop for Windows Credential Manager access. Can also access the Linux keyring natively.

**Native Windows** (Git Bash / MSYS2 / Cygwin): Delegates to `.ps1` scripts.

Each Windows-relevant provider has two files:
- `windows-credential.sh` — bash wrapper that detects context and delegates
- `windows-credential.ps1` — pure PowerShell implementation

The `.ps1` script accepts a uniform CLI interface:

```powershell
# windows-credential.ps1
param(
    [Parameter(Mandatory)][string]$Action,  # available|authenticated|get|list|store|cache_token|get_cached_token
    [string]$Key,
    [string]$Value,
    [int]$Ttl = 3600
)
```

The `.sh` wrapper calls it:

```bash
provider_get_secret() {
    local key="$1"
    powershell.exe -NoProfile -ExecutionPolicy Bypass \
        -File "${PROVIDERS_DIR}/windows-credential.ps1" \
        -Action get -Key "$key" | tr -d '\r'
}
```

On WSL, the wrapper detects the environment and chooses interop vs native Linux keyring:

```bash
if [[ "$PLATFORM" == "wsl" ]]; then
    # Can access both Windows Credential Manager (via powershell.exe)
    # and Linux keyring (via secret-tool) — prefer Windows for consistency
    ...
elif [[ "$PLATFORM" == "windows" ]]; then
    # Native Windows: delegate to .ps1
    ...
fi
```

### Secret Mapping — Hybrid Approach

**Convention-based**: Secrets are stored under a `machine-setup/` namespace in the provider. Folder structure mirrors the repo purpose:
- `machine-setup/backup/restic-password`
- `machine-setup/backup/b2-account-id`
- `machine-setup/backup/b2-account-key`
- `machine-setup/ssh/id_ed25519`
- `machine-setup/ssh/id_ed25519.pub`
- `machine-setup/gpg/private-key`

**Override config** (`secrets.conf`) for custom mappings when convention doesn't fit:

```ini
[provider]
# Which provider to use: 1password, bitwarden, keeper, apple-keychain,
# windows-credential, linux-keyring
name = 1password

# Provider-specific settings
vault = Personal

# Which keychain to use for caching session tokens
# Set to "none" to disable caching
cache_backend = apple-keychain

[secret.restic-password]
provider_key = machine-setup/backup/restic-password
dest = ini
dest_file = backup/restic-config.conf
dest_section = repository
dest_key = password

[secret.b2-account-id]
provider_key = machine-setup/backup/b2-account-id
dest = ini
dest_file = backup/restic-config.conf
dest_section = b2
dest_key = account_id

[secret.b2-account-key]
provider_key = machine-setup/backup/b2-account-key
dest = ini
dest_file = backup/restic-config.conf
dest_section = b2
dest_key = account_key

[secret.ssh-key]
provider_key = machine-setup/ssh/id_ed25519
dest = file
dest_file = dotfiles/profiles/minimal/.ssh/id_ed25519
dest_mode = 0600

[secret.ssh-pub]
provider_key = machine-setup/ssh/id_ed25519.pub
dest = file
dest_file = dotfiles/profiles/minimal/.ssh/id_ed25519.pub
dest_mode = 0644

[secret.gpg-key]
provider_key = machine-setup/gpg/private-key
dest = file
dest_file = dotfiles/secrets/gpg-private.asc
dest_mode = 0600

[secret.env-github-token]
provider_key = machine-setup/tokens/github
dest = env
dest_var = GITHUB_TOKEN
```

### Secret Routing — No Plaintext on Disk

Three destination modes:

1. **`dest = ini`** — Update a key in an INI config file. The orchestrator verifies the file is covered by git-crypt rules (checks `dotfiles/.gitattributes`) before writing. Uses the existing `ini-parser.sh` for reads, sed for writes.

2. **`dest = file`** — Write the secret value to a file path. The orchestrator verifies the path matches a git-crypt rule before writing. Sets permissions via `dest_mode`. Binary secrets are base64-decoded on write.

3. **`dest = env`** — Export as an environment variable for the current session only. Never touches disk. Useful for tokens needed by other setup scripts.

**Safety check**: Before writing ANY file, the routing layer:
1. Resolves the absolute path
2. Checks if the path is covered by a `.gitattributes` filter=git-crypt rule
3. If not covered AND the file is inside the repo, refuses to write and prints an error: `"Refusing to write unencrypted secret to <path> — not covered by git-crypt rules"`
4. Files outside the repo (e.g., `~/.ssh/id_ed25519` linked via dotfiles) are allowed since they're not tracked by git

### CLI Integration

New `--secrets` subcommand on `setup.sh`:

```bash
./setup.sh --secrets pull            # Pull all mapped secrets from provider to destinations
./setup.sh --secrets push            # Push local secrets to provider (for initial population)
./setup.sh --secrets list            # List configured secret mappings and their status
./setup.sh --secrets status          # Show which secrets exist in provider vs populated locally
./setup.sh --secrets set-provider    # Interactive: choose and configure a provider
./setup.sh --secrets init            # Create secrets.conf from template, guided setup
```

During normal `setup.sh` execution (no `--secrets` flag), the system:
1. Checks if `secrets.conf` exists
2. If yes, prompts: "Pull secrets from <provider>? [Y/n]"
3. If user confirms, runs the equivalent of `--secrets pull`
4. If no `secrets.conf`, skips silently

### Provider Detection Order

When no provider is configured in `secrets.conf`:
1. Check for `op` (1Password CLI)
2. Check for `bw` (Bitwarden CLI)
3. Check for `keeper` (Keeper CLI)
4. Check for OS keychain (`security` on macOS, `secret-tool` on Linux, `cmdkey` on Windows)
5. If nothing found, log info and skip

### File Structure

```
scripts/secrets/
├── secrets-manager.sh              # Orchestrator: provider detection, secret pull/push
├── secret-routing.sh               # Destination routing: git-crypt check, INI inject, file write, env export
└── providers/
    ├── 1password.sh                # 1Password provider (op CLI)
    ├── bitwarden.sh                # Bitwarden provider (bw CLI)
    ├── keeper.sh                   # Keeper provider (keeper CLI)
    ├── apple-keychain.sh           # macOS Keychain provider (security command)
    ├── linux-keyring.sh            # Linux libsecret provider (secret-tool)
    ├── windows-credential.sh       # Windows provider bash wrapper (detects WSL vs native)
    └── windows-credential.ps1      # Windows Credential Manager pure PowerShell implementation

secrets.conf.example                # Example mapping config with documentation
```

### Integration with Existing Setup Flow

The secrets system integrates at two points in `setup.sh`:

1. **Early in main()** — after `ensure_repo` and `detect_platform`, before package installation. This ensures secrets like Docker registry credentials are available before packages are installed.

2. **Via `--secrets` subcommand** — standalone operation for managing secrets outside of full setup.

### Testing Strategy

Tests use bats-core with mocked provider CLIs:

- `tests/bats/secrets-manager.bats` — orchestrator tests (provider detection, routing)
- `tests/bats/secret-routing.bats` — destination mode tests (git-crypt check, INI injection, file write, env export)
- `tests/bats/provider-interface.bats` — verify all providers implement required functions
- Provider-specific tests mock the CLI tools (e.g., create a fake `op` script that returns known values)

### Error Handling

- Provider CLI not installed: skip with warning, suggest install command
- Provider not authenticated: prompt to authenticate, cache token in keychain if available
- Secret not found in provider: warn per-secret, continue with remaining secrets
- Git-crypt not unlocked: error on file/INI writes, suggest `git-crypt unlock`
- Network failure: error with retry suggestion
- Partial failure: report summary of succeeded/failed/skipped secrets at the end

### Security Invariants

1. Secret values are NEVER logged (not even in `--dry-run` — show key names only)
2. Secret values are NEVER written to unencrypted files inside the git repo
3. Temp files for binary secrets use `mktemp` with `trap` cleanup and `0600` permissions
4. Provider session tokens are cached in the OS keychain, not in files
5. `secrets.conf` itself contains NO secret values — only mappings (key names and destinations)
