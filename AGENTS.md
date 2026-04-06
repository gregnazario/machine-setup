# AGENTS.md - Guide for AI Agents

This document provides comprehensive guidance for AI agents working with this machine setup repository.

## Repository Overview

This is a **cross-platform machine configuration and syncing system** that:
- Manages packages across 18 different operating systems
- Uses a profile-based system (minimal, full, selfhosted, custom)
- Syncs dotfiles via Syncthing
- Encrypts secrets with git-crypt
- Backs up data with Restic
- Provides health checks, dry-run diffs, and profile validation
- Includes a Nix flake for reproducible dev shells

## Architecture

### Core Components

1. **Package Management** (`packages/`)
   - `common.conf`: Universal package definitions in INI format
   - `platforms/*.conf`: Platform-specific packages and configurations
   - Package mapping system handles different package names across platforms

2. **Profile System** (`profiles/`)
   - INI-based configurations with inheritance
   - Controls: packages, dotfiles, services, setup scripts
   - Extensible -- users can create custom profiles via `--create-profile`

3. **Setup Scripts** (`scripts/`)
   - `setup.sh`: Main entry point
   - `scripts/lib/common.sh`: Shared logging library used by all scripts
   - `scripts/platform-detect.sh`: OS detection logic
   - `scripts/profile-loader.sh`: Profile loading and INI merging
   - `scripts/ini-parser.sh`: Pure-bash INI parser (supports inline comments)
   - `scripts/install-packages.sh`: Cross-platform package installer
   - `scripts/link-dotfiles.sh`: Symlink manager
   - Platform-specific utilities in `scripts/utils/`

4. **Dotfiles** (`dotfiles/`)
   - Organized by profile: `profiles/minimal/`, `profiles/full/`
   - Syncthing synced directory
   - git-crypt encrypted secrets

5. **Testing** (`tests/`)
   - Uses bats-core with git submodules in `tests/libs/`
   - Tests in `tests/bats/*.bats`
   - Runner script: `tests/run-tests.sh`

6. **Nix Flake** (`flake.nix`)
   - Provides `nix develop` for minimal and full dev shell profiles

## Important Patterns

### Platform Detection

The system detects platforms in this order:
1. macOS (Darwin)
2. FreeBSD
3. WSL2 (Linux kernel string contains "microsoft")
4. Native Windows (Git Bash / MSYS2 / Cygwin)
5. Termux (Android, via `$ANDROID_ROOT` or `$PREFIX`)
6. ChromeOS (Crostini, via `/dev/.cros_milestone`)
7. Linux distributions (via `/etc/os-release`)

```bash
source scripts/platform-detect.sh
detect_platform
echo $PLATFORM  # e.g., "fedora", "ubuntu", "macos", "wsl", "termux"
echo $PACKAGE_MANAGER  # e.g., "dnf", "apt", "homebrew", "termux-pkg"
```

### Shared Logging

All scripts source `scripts/lib/common.sh` which provides `log_info`, `log_warn`, `log_error`, and `log_success` functions with color output. A double-source guard prevents re-initialization.

### Profile Inheritance

Profiles can extend other profiles using INI format:
```ini
[profile]
name = full
extends = minimal

[packages]
extra = additional-tool
```

The `profile-loader.sh` merges INI configurations using pure bash.

### Package Mapping

Some packages have different names on different platforms. Mappings are defined in INI sections within `packages/common.conf`:

```ini
[package_mapping.fd-find]
ubuntu = fd-find
void = fd
gentoo = sys-apps/fd
macos = fd
nixos = fd
termux = fd
```

The `install-packages.sh` script uses `get_mapped_package_name()` to resolve names.

### Homebrew Integration

On macOS, the installer generates a temporary Brewfile and uses `brew bundle` to install packages. This handles formulas, casks, and taps natively.

### INI Parser

The custom INI parser (`scripts/ini-parser.sh`) is pure bash with no external dependencies. It supports:
- Section headers: `[section]`
- Key-value pairs: `key = value`
- Full-line comments: lines starting with `#` or `;`
- Inline comments: content after ` #` or ` ;` is stripped
- Last-match-wins semantics for merged files

### Symlink Strategy

Dotfiles are symlinked, not copied:
```bash
~/dotfiles/profiles/full/.config/nvim/init.lua
  -> ~/.config/nvim/init.lua
```

Existing files are backed up with timestamps before linking. Symlinks can be removed with `--unlink`.

## File Locations

### Configuration Files

| File | Purpose |
|------|---------|
| `packages/common.conf` | Universal package definitions (INI format) |
| `packages/platforms/*.conf` | Platform-specific packages (18 platform files) |
| `profiles/*.conf` | Profile definitions (minimal, full, selfhosted) |
| `profiles/hermes/base.conf` | Hermes AI agent profile (extends minimal) |
| `profiles/zeroclaw/base.conf` | Zeroclaw AI agent profile (extends minimal) |
| `backup/restic-config.conf` | Backup configuration (git-crypt encrypted) |
| `dotfiles/.gitattributes` | git-crypt encryption rules |
| `flake.nix` | Nix flake for dev shells |

### Scripts

| Script | Purpose |
|--------|---------|
| `setup.sh` | Main entry point, orchestrates setup |
| `scripts/lib/common.sh` | Shared logging library (`log_info`, `log_warn`, `log_error`, `log_success`) |
| `scripts/platform-detect.sh` | OS and package manager detection |
| `scripts/profile-loader.sh` | Profile loading, inheritance, and INI merging |
| `scripts/ini-parser.sh` | Pure-bash INI parser with inline comment support |
| `scripts/install-packages.sh` | Install packages using detected package manager |
| `scripts/link-dotfiles.sh` | Create symlinks from dotfiles |
| `scripts/unlink-dotfiles.sh` | Remove dotfile symlinks |
| `scripts/check-health.sh` | Verify health of current setup |
| `scripts/dry-run-diff.sh` | Show colored diff of what would change |
| `scripts/validate-profile.sh` | Validate a profile's INI configuration |
| `scripts/setup-docker-repo.sh` | Add Docker repo with GPG fingerprint verification |
| `scripts/setup-syncthing.sh` | Configure Syncthing |
| `scripts/setup-backup.sh` | Configure Restic backups |
| `scripts/setup-ssh-agent.sh` | Configure SSH agent |
| `scripts/setup-docker.sh` | Add user to docker group |
| `scripts/setup-selfhosted.sh` | Self-hosted server setup (Docker Compose stack) |
| `scripts/setup-hermes.sh` | Hermes AI agent: platform gate, install, backend/gateway selection, native wizard delegation |
| `scripts/setup-zeroclaw.sh` | Zeroclaw AI agent: platform gate, install, backend/gateway selection, native wizard delegation |
| `scripts/backup-selfhosted.sh` | Backup for self-hosted services |

### CLI Commands

The main `setup.sh` supports the following flags:

| Flag | Purpose |
|------|---------|
| `--dry-run` | Show what would be done without executing |
| `--check` | Check health of current setup |
| `--validate-profile <name>` | Validate a profile's configuration |
| `--create-profile <name>` | Create a new profile from template |
| `--unlink` | Remove dotfile symlinks (use with `--profile`) |
| `--profile <name>` | Select a profile (minimal, full, selfhosted, or custom) |

## Supported Platforms

| Platform | Package Manager | Detection Method |
|----------|----------------|------------------|
| Fedora | dnf | `/etc/os-release` ID=fedora |
| Ubuntu | apt | `/etc/os-release` ID=ubuntu |
| Debian | apt | `/etc/os-release` ID=debian |
| Gentoo | emerge | `/etc/os-release` ID=gentoo |
| Void | xbps | `/etc/os-release` ID=void |
| Arch | pacman | `/etc/os-release` ID=arch, manjaro, endeavouros, garuda |
| Alpine | apk | `/etc/os-release` ID=alpine |
| OpenSUSE | zypper | `/etc/os-release` ID=opensuse* |
| Rocky | dnf | `/etc/os-release` ID=rocky |
| Alma | dnf | `/etc/os-release` ID=almalinux |
| RaspberryPiOS | apt | `/etc/os-release` ID=raspbian |
| NixOS | nix | `/etc/os-release` ID=nixos |
| macOS | homebrew | `uname` = Darwin |
| FreeBSD | pkg | `uname` = FreeBSD |
| Windows 11 | winget | `uname -s` matches MINGW*/MSYS*/CYGWIN* |
| WSL2 | apt | `uname -r` contains "microsoft" |
| Termux | termux-pkg | `$ANDROID_ROOT` or `$PREFIX` contains com.termux |
| ChromeOS | apt | `/dev/.cros_milestone` or `$CHROMEOS_RELEASE_NAME` |

## Profile System Details

### Minimal Profile
- **Target**: Servers, resource-constrained systems (Raspberry Pi)
- **Packages**: nushell, neovim, ripgrep, fd-find, fzf, git, mise, gnupg, openssh
- **Services**: sshd only
- **Default on**: RaspberryPiOS

### Full Profile
- **Target**: Development workstations
- **Packages**: Everything in minimal + zellij, bat, eza, dust, bottom, procs, jq, httpie, docker, kubectl, etc.
- **Services**: sshd, docker
- **Default on**: All other platforms

### Selfhosted Profile
- **Target**: Self-hosted servers running Docker Compose stacks
- **Setup**: Docker Compose with monitoring, reverse proxy, etc.

### AI Agent Profiles

Nested sub-profiles for on-machine AI agents. Each uses a dedicated setup script
with a "hybrid wizard" pattern: our script handles high-level choices (backend,
gateways), then delegates to the tool's native wizard for details (API keys, etc.).

#### Hermes (`profiles/hermes/base.conf`)
- **Tool**: Hermes by Nous Research (https://hermes-agent.nousresearch.com/)
- **Install**: curl-based (`scripts/setup-hermes.sh`)
- **Backends**: Nous Portal (OAuth), OpenRouter (API key), custom OpenAI-compatible endpoint
- **Gateways**: Telegram, Discord, Slack, WhatsApp, Signal, Email
- **Platforms**: Linux, macOS, WSL2 (not Windows)
- **Config dir**: `~/.config/hermes/`
- **Native CLI**: `hermes setup`, `hermes gateway setup`, `hermes update`

#### Zeroclaw (`profiles/zeroclaw/base.conf`)
- **Tool**: Zeroclaw by Zeroclaw Labs (https://www.zeroclawlabs.ai/)
- **Install**: curl-based (`scripts/setup-zeroclaw.sh`)
- **Backends**: Claude (Anthropic), OpenAI, local models
- **Gateways**: Telegram, Discord, WhatsApp, Slack
- **Platforms**: Linux, macOS, Windows, WSL2
- **Config dir**: `~/.config/zeroclaw/`
- **100% local processing** -- no cloud requirement

### Profile Structure (INI format)

```ini
[profile]
name = profile-name
description = Human-readable description
extends = minimal

[packages]
category = package1 package2 package3

[dotfiles]
source = profiles/profile-name/

[dotfiles.links.1]
src = shell/.config/nushell/
dest = ~/.config/nushell/

[services]
enabled = sshd docker

[setup_scripts]
run = scripts/setup-something.sh
```

## Testing

### Test Framework

Tests use bats-core with helper libraries as git submodules:
- `tests/libs/bats-core` -- test runner
- `tests/libs/bats-assert` -- assertion helpers
- `tests/libs/bats-support` -- output formatting

Run all tests:
```bash
./tests/run-tests.sh
```

Individual test files are in `tests/bats/` and cover: INI parsing, profile loading, dotfiles linking/unlinking, platform detection, WSL detection, health checks, dry-run diffs, package collections, Brewfile generation, Nix flake, idempotency, and more.

### Dry Run Mode

All major scripts support `--dry-run`. The `dry-run-diff.sh` script provides a colored diff showing exactly what would change:
```bash
./setup.sh --dry-run
./scripts/install-packages.sh --dry-run
./scripts/link-dotfiles.sh --dry-run
```

### Health Check

Verify the state of an existing setup:
```bash
./setup.sh --check --profile full
```

### Profile Validation

Validate a profile's INI structure:
```bash
./setup.sh --validate-profile my-profile
```

### Testing on New Machine

1. Clone repository (with submodules: `git clone --recurse-submodules`)
2. Run `./setup.sh --dry-run` to see what would happen
3. Run `./setup.sh --profile minimal` for minimal test
4. Verify with `./setup.sh --check --profile minimal`

## Secrets Management

### git-crypt

Files matching patterns in `dotfiles/.gitattributes` are automatically encrypted:
- `secrets/**` -- All secrets
- `**/.ssh/id_*` -- SSH private keys
- `**/*.gpg` -- GPG keys
- `**/api-tokens/**` -- API tokens
- `backup/restic-config.conf` -- Backup credentials

**Important**: When working with secrets:
1. Never commit unencrypted secrets
2. Use `git-crypt lock` before pushing
3. Use `git-crypt unlock` on new machines

## Common Tasks

### Adding a New Package

1. Add to `packages/common.conf` under appropriate category
2. If package has different names, add a `[package_mapping.name]` section
3. Test with `./setup.sh --dry-run`

### Creating a New Profile

1. Run `./setup.sh --create-profile my-profile` to scaffold from template
2. Edit `profiles/my-profile.conf` (set `extends = minimal` or `extends = full`)
3. Add packages, dotfiles, services
4. Create dotfiles in `dotfiles/profiles/my-profile/`
5. Validate with `./setup.sh --validate-profile my-profile`
6. Test with `./setup.sh --profile my-profile --dry-run`

### Supporting a New Platform

1. Create `packages/platforms/newplatform.conf`
2. Add platform detection logic to `scripts/platform-detect.sh`
3. Add package installation function to `scripts/install-packages.sh`
4. Test on the target platform

### Modifying Dotfiles

1. Edit files in `dotfiles/profiles/<profile>/`
2. Profile-specific configs are in subdirectories
3. Changes sync via Syncthing automatically
4. To test: `./scripts/link-dotfiles.sh --profile <profile> --force`
5. To remove: `./scripts/unlink-dotfiles.sh --profile <profile>`

## Docker GPG Verification

The `scripts/setup-docker-repo.sh` script adds the Docker repository with GPG fingerprint verification. It:
- Downloads Docker's official GPG key
- Verifies the key fingerprint matches the known value
- Warns and re-downloads if the fingerprint does not match
- Configures the appropriate apt repository

## Known Limitations

1. **Gentoo**: Requires manual USE flag configuration for some packages
2. **FreeBSD**: Ports compilation requires manual intervention
3. **Syncthing**: Device pairing must be done manually via web UI
4. **git-crypt**: Requires GPG key to be available before unlocking
5. **ChromeOS**: Requires Crostini (Linux container) to be enabled first

## Dependencies

### Required
- `bash` (4.0+)
- `git`

### Optional (installed by setup)
- `git-crypt` -- for secrets encryption
- `syncthing` -- for dotfiles sync
- `restic` -- for backups
- `mise` -- for runtime version management
- `nix` -- for Nix flake dev shells (NixOS or standalone)

## Troubleshooting Guide

### Issue: Platform not detected

**Symptoms**: Script fails with "Unable to detect platform"

**Solution**:
1. Check if `/etc/os-release` exists
2. Verify the `ID` field matches expected values
3. For WSL2, confirm `uname -r` contains "microsoft"
4. For Termux, confirm `$ANDROID_ROOT` or `$PREFIX` is set
5. For ChromeOS, confirm `/dev/.cros_milestone` exists
6. Add custom detection logic to `platform-detect.sh`

### Issue: Package installation fails

**Symptoms**: Package manager errors

**Solution**:
1. Check package name mapping in `common.conf`
2. Verify repository is enabled (for third-party repos)
3. Check platform-specific package file for repo configuration
4. Try installing package manually with detected package manager

### Issue: Dotfiles not linking

**Symptoms**: Symlinks not created, or point to wrong location

**Solution**:
1. Check profile `[dotfiles] source` path is correct
2. Verify source files exist in `dotfiles/profiles/<profile>/`
3. Use `--force` flag to overwrite existing files
4. Check for symlink loops or permission issues
5. Use `--unlink` then re-link if symlinks are stale

### Issue: git-crypt unlock fails

**Symptoms**: "error: no GPG secret key"

**Solution**:
1. Import GPG key: `gpg --import key.asc`
2. Trust the key: `gpg --edit-key KEY_ID trust` (set to 5)
3. Verify with `gpg --list-secret-keys`
4. Run `git-crypt unlock` again

### Issue: Backup fails with auth error

**Symptoms**: Restic can't connect to B2/S3

**Solution**:
1. Verify credentials in `backup/restic-config.conf`
2. Check bucket exists and is accessible
3. Test credentials with `b2 authorize-account` or `aws s3 ls`
4. Ensure `restic-config.conf` is not encrypted (unlock git-crypt first)

## Code Style Guidelines

### Bash Scripts
- Use `#!/usr/bin/env bash` shebang
- Enable strict mode: `set -euo pipefail`
- Source `scripts/lib/common.sh` for logging (do not define local log functions)
- Use `[[ ]]` for tests, not `[ ]`
- Quote variables: `"$var"`
- Use functions for reusable code

### INI Files
- Use spaces around `=` in key-value pairs: `key = value`
- Include descriptions for packages via comments
- Group related items with section headers
- Multiple values on one key use space separation: `packages = pkg1 pkg2 pkg3`
- Validate format before committing

### Documentation
- Keep README.md user-focused
- Update AGENTS.md for developer/agent guidance
- Add inline comments for complex logic
- Include examples in documentation

## Version Control

### Commit Messages

Use conventional commits:
```
feat: add support for new platform
fix: resolve package mapping issue
docs: update installation instructions
refactor: improve profile loading logic
test: add dry-run mode to setup script
```

### Branches

- `main` -- stable, production-ready
- `develop` -- integration branch
- `feature/*` -- new features
- `fix/*` -- bug fixes
- `docs/*` -- documentation updates
- `improvements/*` -- improvement rounds

## Security Considerations

1. **Never commit unencrypted secrets**
2. **Always use GPG signing for commits**
3. **Review `.gitattributes` before adding new file types**
4. **Test backup restore procedure quarterly**
5. **Keep git-crypt keys backed up securely**
6. **Use strong passwords for backup encryption**
7. **Docker GPG keys are fingerprint-verified** by `setup-docker-repo.sh`

## Performance Notes

- Profile loading with inheritance: ~100ms
- Package installation: varies (5-30 minutes depending on profile)
- Dotfile linking: ~1-2 seconds
- Full setup on fresh machine: ~20-45 minutes (depends on network speed)

## Future Enhancements

Potential areas for improvement:
- Create web UI for profile management
- Integration with password managers (1Password, Bitwarden)
- Plugin system (`custom/` directory for user extensions)
- Version pinning (`package=version` syntax in INI configs)

## Getting Help

1. Check README.md for user documentation
2. Review PLAN.md for architecture details
3. Examine example files (`*.example`)
4. Run with `--dry-run` to diagnose issues
5. Run with `--check` to verify current setup health
6. Check logs in `~/backup.log` for backup issues

## Agent-Specific Notes

When modifying this repository:
1. Always test changes with `--dry-run` first
2. Ensure INI files are valid before committing (use `--validate-profile`)
3. Update both README.md and AGENTS.md for significant changes
4. Verify git-crypt is not encrypting files it shouldn't
5. Test profile inheritance chains thoroughly
6. Keep platform-specific logic isolated in appropriate files
7. Maintain backward compatibility with existing profiles
8. Document any new dependencies or requirements
9. Use `scripts/lib/common.sh` for logging -- never define local log functions
10. Run `tests/run-tests.sh` to verify nothing is broken

## Docs

Additional documentation can be found in the `docs/` folder (if present).

## Contact

For questions about this repository:
- Review existing documentation (README.md, PLAN.md, AGENTS.md)
- Check closed GitHub issues
- Open a new issue with detailed information

---

**Last Updated**: 2026-04-05
**Version**: 2.0.0
