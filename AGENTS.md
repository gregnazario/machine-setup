# AGENTS.md - Guide for AI Agents

This document provides comprehensive guidance for AI agents working with this machine setup repository.

## Repository Overview

This is a **cross-platform machine configuration and syncing system** that:
- Manages packages across 8 different operating systems
- Uses a profile-based system (minimal, full, custom)
- Syncs dotfiles via Syncthing
- Encrypts secrets with git-crypt
- Backs up data with Restic

## Architecture

### Core Components

1. **Package Management** (`packages/`)
   - `common.yaml`: Universal package definitions with metadata
   - `platforms/*.yaml`: Platform-specific packages and configurations
   - Package mapping system handles different package names across platforms

2. **Profile System** (`profiles/`)
   - YAML-based configurations with inheritance
   - Controls: packages, dotfiles, services, setup scripts
   - Extensible - users can create custom profiles

3. **Setup Scripts** (`scripts/`)
   - `setup.sh`: Main entry point
   - `platform-detect.sh`: OS detection logic
   - `profile-loader.sh`: Profile loading and inheritance
   - `install-packages.sh`: Cross-platform package installer
   - `link-dotfiles.sh`: Symlink manager
   - Platform-specific utilities in `utils/`

4. **Dotfiles** (`dotfiles/`)
   - Organized by profile: `profiles/minimal/`, `profiles/full/`
   - Syncthing synced directory
   - git-crypt encrypted secrets

## Important Patterns

### Platform Detection

The system detects platforms in this order:
1. macOS (Darwin)
2. FreeBSD
3. WSL (Windows Subsystem for Linux)
4. Linux distributions (via `/etc/os-release`)

```bash
source scripts/platform-detect.sh
detect_platform
echo $PLATFORM  # e.g., "fedora", "ubuntu", "macos"
echo $PACKAGE_MANAGER  # e.g., "dnf", "apt", "homebrew"
```

### Profile Inheritance

Profiles can extend other profiles:
```yaml
extends: minimal  # Inherit everything from minimal
packages:
  extra:  # Add to inherited packages
    - additional-tool
```

The `profile-loader.sh` merges YAML configurations using `yq`.

### Package Mapping

Some packages have different names on different platforms:

```yaml
# packages/common.yaml
package_mapping:
  fd-find:
    ubuntu: fd-find
    void: fd
    gentoo: sys-apps/fd
```

The `install-packages.sh` script uses `get_mapped_package_name()` to resolve names.

### Symlink Strategy

Dotfiles are symlinked, not copied:
```bash
~/dotfiles/profiles/full/.config/nvim/init.lua
  → ~/.config/nvim/init.lua
```

Existing files are backed up with timestamps before linking.

## File Locations

### Configuration Files

| File | Purpose |
|------|---------|
| `packages/common.yaml` | Universal package definitions |
| `packages/platforms/*.yaml` | Platform-specific packages |
| `profiles/*.yaml` | Profile definitions |
| `backup/restic-config.yaml` | Backup configuration (git-crypt encrypted) |
| `dotfiles/.gitattributes` | git-crypt encryption rules |

### Scripts

| Script | Purpose |
|--------|---------|
| `setup.sh` | Main entry point, orchestrates setup |
| `scripts/platform-detect.sh` | OS detection |
| `scripts/profile-loader.sh` | Profile loading and YAML merging |
| `scripts/install-packages.sh` | Install packages using detected package manager |
| `scripts/link-dotfiles.sh` | Create symlinks from dotfiles |
| `scripts/setup-syncthing.sh` | Configure Syncthing |
| `scripts/setup-backup.sh` | Configure Restic backups |
| `scripts/setup-ssh-agent.sh` | Configure SSH agent |
| `scripts/setup-docker.sh` | Add user to docker group |

## Supported Platforms

| Platform | Package Manager | Detection Method |
|----------|----------------|------------------|
| Fedora | dnf | `/etc/os-release` ID=fedora |
| Ubuntu | apt | `/etc/os-release` ID=ubuntu |
| RaspberryPiOS | apt | `/etc/os-release` ID=raspbian |
| Gentoo | emerge | `/etc/os-release` ID=gentoo |
| Void | xbps | `/etc/os-release` ID=void |
| macOS | homebrew | `uname` = Darwin |
| FreeBSD | pkg | `uname` = FreeBSD |
| Windows 11 | winget | `uname -r` contains "Microsoft" |

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

### Profile Structure

```yaml
name: profile-name
description: Human-readable description
extends: base-profile  # or null

packages:
  category:
    - package1
    - package2

dotfiles:
  source: profiles/profile-name/
  links:
    - src: relative/path/in/dotfiles
      dest: ~/target/path

services:
  - service-name

setup_scripts:
  - scripts/setup-something.sh
```

## Secrets Management

### git-crypt

Files matching patterns in `dotfiles/.gitattributes` are automatically encrypted:
- `secrets/**` - All secrets
- `**/.ssh/id_*` - SSH private keys
- `**/*.gpg` - GPG keys
- `**/api-tokens/**` - API tokens
- `backup/restic-config.yaml` - Backup credentials

**Important**: When working with secrets:
1. Never commit unencrypted secrets
2. Use `git-crypt lock` before pushing
3. Use `git-crypt unlock` on new machines

## Common Tasks

### Adding a New Package

1. Add to `packages/common.yaml` under appropriate category
2. If package has different names, add to `package_mapping` section
3. Test with `./setup.sh --dry-run`

### Creating a New Profile

1. Create `profiles/my-profile.yaml`
2. Set `extends: minimal` or `extends: full`
3. Add packages, dotfiles, services
4. Create dotfiles in `dotfiles/profiles/my-profile/`
5. Test with `./setup.sh --profile my-profile --dry-run`

### Supporting a New Platform

1. Create `packages/platforms/newplatform.yaml`
2. Add platform detection logic to `scripts/platform-detect.sh`
3. Add package installation function to `scripts/install-packages.sh`
4. Test on the target platform

### Modifying Dotfiles

1. Edit files in `dotfiles/profiles/<profile>/`
2. Profile-specific configs are in subdirectories
3. Changes sync via Syncthing automatically
4. To test: `./scripts/link-dotfiles.sh --profile <profile> --force`

## Testing

### Dry Run Mode

All major scripts support `--dry-run`:
```bash
./setup.sh --dry-run
./scripts/install-packages.sh --dry-run
./scripts/link-dotfiles.sh --dry-run
```

### Testing on New Machine

1. Clone repository
2. Run `./setup.sh --dry-run` to see what would happen
3. Run `./setup.sh --profile minimal` for minimal test
4. Verify with `./setup.sh --profile full --no-backup`

### Validation Checklist

When making changes, verify:
- [ ] Platform detection works correctly
- [ ] Profile loading succeeds
- [ ] Package mapping resolves correctly
- [ ] Dotfiles symlink properly
- [ ] No unencrypted secrets are committed
- [ ] Backup script runs without errors
- [ ] Syncthing config is valid

## Known Limitations

1. **Windows**: WSL setup is manual, not automated
2. **Gentoo**: Requires manual USE flag configuration for some packages
3. **FreeBSD**: Ports compilation requires manual intervention
4. **Syncthing**: Device pairing must be done manually via web UI
5. **git-crypt**: Requires GPG key to be available before unlocking

## Dependencies

### Required
- `bash` (4.0+)
- `git`
- `yq` (YAML processor) - auto-installed if missing
- `curl` or `wget`

### Optional (installed by setup)
- `git-crypt` - for secrets encryption
- `syncthing` - for dotfiles sync
- `restic` - for backups
- `mise` - for runtime version management

## Troubleshooting Guide

### Issue: Platform not detected

**Symptoms**: Script fails with "Unable to detect platform"

**Solution**: 
1. Check if `/etc/os-release` exists
2. Verify the `ID` field matches expected values
3. Add custom detection logic to `platform-detect.sh`

### Issue: Package installation fails

**Symptoms**: Package manager errors

**Solution**:
1. Check package name mapping in `common.yaml`
2. Verify repository is enabled (for third-party repos)
3. Check platform-specific package file for repo configuration
4. Try installing package manually with detected package manager

### Issue: Dotfiles not linking

**Symptoms**: Symlinks not created, or point to wrong location

**Solution**:
1. Check profile `dotfiles.source` path is correct
2. Verify source files exist in `dotfiles/profiles/<profile>/`
3. Use `--force` flag to overwrite existing files
4. Check for symlink loops or permission issues

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
1. Verify credentials in `backup/restic-config.yaml`
2. Check bucket exists and is accessible
3. Test credentials with `b2 authorize-account` or `aws s3 ls`
4. Ensure `restic-config.yaml` is not encrypted (unlock git-crypt first)

## Code Style Guidelines

### Bash Scripts
- Use `#!/usr/bin/env bash` shebang
- Enable strict mode: `set -euo pipefail`
- Use `[[ ]]` for tests, not `[ ]`
- Quote variables: `"$var"`
- Use functions for reusable code
- Add logging functions: `log_info`, `log_error`, etc.

### YAML Files
- Use 2 spaces for indentation
- Include descriptions for packages
- Group related items with comments
- Validate with `yq` before committing

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

- `main` - stable, production-ready
- `develop` - integration branch
- `feature/*` - new features
- `fix/*` - bug fixes
- `docs/*` - documentation updates

## Security Considerations

1. **Never commit unencrypted secrets**
2. **Always use GPG signing for commits**
3. **Review `.gitattributes` before adding new file types**
4. **Test backup restore procedure quarterly**
5. **Keep git-crypt keys backed up securely**
6. **Use strong passwords for backup encryption**

## Performance Notes

- Profile loading with inheritance: ~100ms
- Package installation: varies (5-30 minutes depending on profile)
- Dotfile linking: ~1-2 seconds
- Full setup on fresh machine: ~20-45 minutes (depends on network speed)

## Future Enhancements

Potential areas for improvement:
- Add more example profiles (e.g., gaming, data science)
- Implement idempotent package installation
- Add rollback capability for failed setups
- Create web UI for profile management
- Add automated testing with VMs/containers
- Support for additional package managers (nix, guix)
- Integration with password managers (1Password, Bitwarden)

## Getting Help

1. Check README.md for user documentation
2. Review PLAN.md for architecture details
3. Examine example files (`*.example`)
4. Run with `--dry-run` to diagnose issues
5. Check logs in `~/backup.log` for backup issues

## Agent-Specific Notes

When modifying this repository:
1. Always test changes with `--dry-run` first
2. Ensure YAML files are valid before committing
3. Update both README.md and AGENTS.md for significant changes
4. Verify git-crypt is not encrypting files it shouldn't
5. Test profile inheritance chains thoroughly
6. Keep platform-specific logic isolated in appropriate files
7. Maintain backward compatibility with existing profiles
8. Document any new dependencies or requirements

## Docs

Additional documentation can be found in the `docs/` folder (if present).

## Contact

For questions about this repository:
- Review existing documentation (README.md, PLAN.md, AGENTS.md)
- Check closed GitHub issues
- Open a new issue with detailed information

---

**Last Updated**: 2026-03-07
**Version**: 1.0.0
