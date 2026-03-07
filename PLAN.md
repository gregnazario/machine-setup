# Machine Setup Plan

## Overview

Cross-platform machine configuration and syncing system supporting:
- **Linux**: Fedora, Ubuntu, Gentoo, Void, RaspberryPiOS
- **Unix**: macOS, FreeBSD
- **Windows**: Windows 11 (with optional WSL)

## Architecture

### Sync Strategy
- **Dotfiles**: Syncthing (real-time P2P sync)
- **Secrets**: git-crypt (encrypted in git repo)
- **Backup**: Restic → BackBlaze B2 (daily, encrypted)

### Profile System
Extensible YAML-based profiles with inheritance:
- **minimal**: Essential CLI tools (default on RaspberryPiOS)
- **full**: Complete dev environment (default on all other platforms)
- **custom**: Unlimited user-defined profiles

### Package Management
Platform-specific package managers with unified YAML definitions:
- Fedora: dnf
- Ubuntu/RaspberryPiOS: apt
- Gentoo: emerge + binpkg
- Void: xbps
- macOS: Homebrew
- FreeBSD: pkg + ports
- Windows: winget

---

## Repository Structure

```
machine-setup/
├── PLAN.md                           # This document
├── README.md                         # User documentation
├── setup.sh                          # Main setup script
├── packages/
│   ├── common.yaml                   # Universal package definitions
│   ├── platforms/
│   │   ├── macos.yaml
│   │   ├── freebsd.yaml
│   │   ├── fedora.yaml
│   │   ├── ubuntu.yaml
│   │   ├── gentoo.yaml
│   │   ├── void.yaml
│   │   ├── raspberrypios.yaml
│   │   └── windows.yaml
│   └── custom.yaml.example
├── profiles/
│   ├── minimal.yaml
│   ├── full.yaml
│   ├── server.yaml.example
│   └── gaming.yaml.example
├── dotfiles/
│   ├── .gitattributes               # git-crypt config
│   ├── profiles/
│   │   ├── minimal/
│   │   ├── full/
│   │   └── custom/
│   └── secrets/                     # git-crypt encrypted
├── scripts/
│   ├── install-packages.sh
│   ├── link-dotfiles.sh
│   ├── setup-syncthing.sh
│   ├── setup-backup.sh
│   ├── platform-detect.sh
│   ├── profile-loader.sh
│   └── utils/
│       ├── gentoo-setup.sh
│       ├── void-setup.sh
│       └── freebsd-setup.sh
├── secrets/
│   ├── ssh-keys/
│   ├── gpg-keys/
│   ├── api-tokens/
│   └── backup-credentials/
└── backup/
    ├── restic-config.yaml
    └── backup.sh
```

---

## Default Tool Configuration

### Shell & Editor
- **Shell**: nushell
- **Editor**: neovim
- **Multiplexer**: zellij (full profile only)

### Modern CLI Replacements
- **Search**: fzf, ripgrep, fd-find
- **Viewers**: bat, eza, glow
- **System**: bottom/btop, procs, dust, gdu

### Development Tools
- **Languages**: Python 3, Node.js, Rust, Go
- **Version Manager**: mise
- **DevOps**: Docker (OrbStack on macOS), kubectl (optional)
- **Git**: gh (GitHub CLI)

### Utilities
- **Network**: jq, httpie/curlie, doggo, gping
- **Files**: rsync, xcp, yazi/broot, ouch
- **Security**: pass/gopass, gnupg, ssh-agent
- **Other**: asciinema, fastfetch

### Platform-Specific

#### Windows 11
- Package Manager: winget
- Tools: Windows Terminal, PowerShell 7, gsudo, Total Commander
- WSL: Manual setup only

#### FreeBSD
- Package Manager: pkg + ports
- Tools: bsdutils

#### Gentoo
- Features: binpkg enabled, custom USE flags

#### Void
- Features: xbps, void-services, rolling updates

#### RaspberryPiOS
- Default profile: minimal (resource-constrained)
- Package manager: apt

---

## Profile System

### Minimal Profile
**Packages**:
- nushell, neovim
- ripgrep, fd-find, fzf
- git, mise
- gnupg, openssh

**Dotfiles**:
- nushell config
- neovim config
- gitconfig
- SSH config

**Services**: sshd

**Default on**: RaspberryPiOS

**Use case**: Servers, resource-constrained systems

### Full Profile
**Packages** (extends minimal):
- zellij
- bat, eza, dust, bottom, procs
- jq, httpie, doggo, gping
- rsync, yazi, ouch, asciinema, glow, fastfetch
- pass, python3, rustup, gh
- docker, kubectl

**Dotfiles** (extends minimal):
- All minimal dotfiles
- zellij config
- bat, bottom, glow configs
- mise config

**Services**: sshd, docker

**Default on**: Fedora, Ubuntu, Gentoo, Void, macOS, FreeBSD, Windows

**Use case**: Full development workstations

### Custom Profiles
Users can create custom profiles in `profiles/*.yaml`:
- Inherit from `minimal` or `full`
- Add extra packages, dotfiles, services
- Define setup scripts

Example profiles included:
- `server.yaml.example`: minimal + monitoring + networking
- `gaming.yaml.example`: full + gaming tools

---

## Setup Process

### Initial Setup
```bash
# Clone repository
git clone https://github.com/yourusername/machine-setup.git
cd machine-setup

# Run setup (auto-detects profile and platform)
./setup.sh

# Or specify profile explicitly
./setup.sh --profile minimal
./setup.sh --profile full
```

### Setup Steps
1. **Detect platform** (macOS, FreeBSD, Fedora, Ubuntu, Gentoo, Void, RaspberryPiOS, Windows)
2. **Load profile** (auto-detect or via --profile flag)
3. **Resolve profile inheritance** (e.g., full extends minimal)
4. **Install base dependencies** (git, git-crypt, syncthing, mise)
5. **Install packages** from profile + platform packages
6. **Symlink dotfiles** from `dotfiles/profiles/<profile>/`
7. **Unlock git-crypt** (requires GPG key)
8. **Enable services** (sshd, docker, etc.)
9. **Run setup scripts** (ssh-agent, docker, etc.)
10. **Setup Syncthing** (configure and connect devices)
11. **Setup backup** (Restic + daily cron/systemd)
12. **Verify installation**

---

## Package Management

### Platform Detection
Auto-detect OS and map to package manager:
- Fedora → dnf
- Ubuntu/RaspberryPiOS → apt
- Gentoo → emerge
- Void → xbps
- macOS → Homebrew
- FreeBSD → pkg
- Windows → winget

### Package Name Mapping
Some tools have different names across platforms:
```yaml
fd:
  ubuntu: fd-find
  fedora: fd-find
  void: fd
  gentoo: sys-apps/fd
  freebsd: fd-find
  macos: fd
```

### Gentoo Special Handling
- Enable `binpkg` by default for faster installs
- User-defined global `USE` flags in `gentoo.yaml`
- Per-package USE flags supported
- Auto-configure `/etc/portage/make.conf`

### Void Linux Special Handling
- Configure XBPS repositories (nonfree, multilib)
- Enable void-specific services via symlinks
- Rolling update strategy configured

### FreeBSD Special Handling
- Use `pkg` for binary packages (default)
- Support `ports` compilation for custom builds
- Install `bsdutils` for FreeBSD-specific tools
- ZFS support detection

---

## Dotfiles Management

### Strategy
1. Store dotfiles in `~/dotfiles/` (Syncthing synced)
2. Symlink to home directory
3. Profile-specific dotfiles in `dotfiles/profiles/<profile>/`

### Symlink Script
```bash
./scripts/link-dotfiles.sh --profile <profile>
```

Creates symlinks from:
- `dotfiles/profiles/<profile>/*` → `~/`

### Syncthing Configuration
- Shared folder: `~/dotfiles`
- Real-time sync enabled
- Staggered versioning (30 days)
- Ignore: `.git-crypt`, large files, temp files
- TLS enabled, password-protected GUI

---

## Secrets Management

### git-crypt Setup
1. Initialize in dotfiles repo: `git-crypt init`
2. Add GPG keys: `git-crypt add-gpg-user USERID`
3. Configure `.gitattributes`:
   ```
   secrets/** filter=git-crypt diff=git-crypt
   **/.ssh/* filter=git-crypt diff=git-crypt
   **/api-tokens/* filter=git-crypt diff=git-crypt
   ```

### Encrypted Files
- SSH private keys
- GPG private keys
- API tokens (GitHub, cloud providers)
- Backup credentials (BackBlaze B2 keys)

### Workflow
```bash
# Unlock repository (requires GPG key)
git-crypt unlock

# Encrypt new file
git add secrets/new-secret.txt
git commit -m "Add new secret"
```

---

## Backup Strategy

### Restic Configuration
```yaml
repository: b2:your-bucket-name:machine-backup
password: <from-password-manager>
schedule: daily
retention:
  keep-daily: 7
  keep-weekly: 4
  keep-monthly: 12
paths:
  - ~/dotfiles
  - ~/.ssh
  - ~/Documents
  - ~/Projects
excludes:
  - node_modules
  - .git/objects
  - "*.log"
```

### Backup Targets
- Primary: BackBlaze B2 (default)
- Alternative: Any S3-compatible service

### Backup Script
Runs daily at 2 AM via cron/systemd timer.

### Restore Process
```bash
# List snapshots
restic snapshots

# Restore specific snapshot
restic restore <snapshot-id> --target /tmp/restore
```

---

## Security Hardening

### Measures
- **SSH**: Ed25519 keys, disable password auth
- **Git**: Sign commits with GPG
- **Syncthing**: TLS, password-protected GUI, limited access
- **Backup**: Encrypted with strong password + server-side encryption
- **Secrets**: Never in plaintext, always git-crypt encrypted
- **Firewall**: Configure UFW (Linux) or firewall rules
- **Updates**: Auto-update critical security packages

### Monitoring
- Script to verify Syncthing sync status
- Backup success/failure notifications (email/Slack)
- Log aggregation (optional)

---

## Automation

### Cron/Systemd Jobs
- Daily backup at 2 AM
- Weekly package updates check
- Monthly git-crypt key rotation reminder

### Platform-Specific Services
- Linux: systemd timers
- macOS: launchd
- FreeBSD: cron
- Windows: Task Scheduler

---

## Testing & Validation

### Initial Setup Checklist
- [ ] All packages installed
- [ ] Dotfiles symlinked correctly
- [ ] Syncthing connected to all devices
- [ ] git-crypt unlocking works
- [ ] Backup runs successfully
- [ ] Restore test completed
- [ ] All services auto-start on boot

### Ongoing Maintenance
- Monthly: Review package lists, update as needed
- Quarterly: Test restore procedure
- Annually: Rotate sensitive credentials

---

## Documentation Requirements

### README.md Should Include
- Quick start guide
- OS-specific setup instructions
- Profile system documentation
- How to add new packages
- How to add new machines
- How to create custom profiles
- Restore procedures
- Troubleshooting common issues
- Security best practices

---

## Implementation Order

1. Create repository structure
2. Implement package management scripts
3. Create profile system (minimal, full)
4. Setup dotfiles with current configs
5. Initialize git-crypt and add secrets
6. Setup Syncthing on primary machine
7. Configure Restic backup with BackBlaze B2
8. Test full workflow on fresh machine/VM
9. Write comprehensive documentation
10. Test on all supported platforms

---

## Success Criteria

- ✅ Single command setup on any supported platform
- ✅ Minimal profile < 20 packages, full profile < 50 packages
- ✅ Real-time dotfiles sync across all machines
- ✅ Secrets encrypted at rest and in transit
- ✅ Daily automated backups with < 1 hour completion time
- ✅ Restore procedure completes in < 30 minutes
- ✅ Profile switching works without re-installing base tools
- ✅ All platforms tested and documented
