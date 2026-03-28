# Machine Setup Plan

## Overview

Cross-platform machine configuration and syncing system supporting:
- **Linux**: Fedora, Ubuntu, Debian, Gentoo, Void, Arch, Alpine, OpenSUSE, Rocky, Alma, RaspberryPiOS
- **Unix**: macOS, FreeBSD
- **Windows**: Windows 11 (with optional WSL)

## Architecture

### Sync Strategy
- **Dotfiles**: Syncthing (real-time P2P sync)
- **Secrets**: git-crypt (encrypted in git repo)
- **Backup**: Restic → BackBlaze B2 (daily, encrypted)

### Profile System
Extensible INI-based profiles with inheritance:
- **minimal**: Essential CLI tools (default on RaspberryPiOS)
- **full**: Complete dev environment (default on all other platforms)
- **custom**: Unlimited user-defined profiles

### Package Management
Platform-specific package managers with unified INI definitions:
- Fedora/Rocky/Alma: dnf
- Ubuntu/RaspberryPiOS/Debian: apt
- Gentoo: emerge + binpkg
- Void: xbps
- Arch: pacman
- Alpine: apk
- OpenSUSE: zypper
- macOS: Homebrew
- FreeBSD: pkg + ports
- Windows: winget

### Standalone Bootstrap
`setup.sh` can be run from anywhere — if the repo isn't present locally, it
clones it to `~/.machine-setup` (or `$MACHINE_SETUP_DIR`) before proceeding.

---

## Repository Structure

```
machine-setup/
├── PLAN.md                           # This document
├── README.md                         # User documentation
├── setup.sh                          # Main setup script (standalone)
├── packages/
│   ├── common.conf                   # Universal package definitions
│   ├── platforms/
│   │   ├── macos.conf
│   │   ├── freebsd.conf
│   │   ├── fedora.conf
│   │   ├── ubuntu.conf
│   │   ├── debian.conf
│   │   ├── gentoo.conf
│   │   ├── void.conf
│   │   ├── arch.conf
│   │   ├── alpine.conf
│   │   ├── opensuse.conf
│   │   ├── rocky.conf
│   │   ├── alma.conf
│   │   ├── raspberrypios.conf
│   │   └── windows.conf
│   └── custom.conf.example
├── profiles/
│   ├── minimal.conf
│   ├── full.conf
│   ├── server.conf.example
│   └── gaming.conf.example
├── dotfiles/
│   ├── .gitattributes               # git-crypt config
│   └── profiles/
│       ├── minimal/
│       └── full/
├── scripts/
│   ├── ini-parser.sh
│   ├── install-packages.sh
│   ├── link-dotfiles.sh
│   ├── setup-syncthing.sh
│   ├── setup-backup.sh
│   ├── setup-docker.sh
│   ├── setup-ssh-agent.sh
│   ├── platform-detect.sh
│   ├── profile-loader.sh
│   └── utils/
│       ├── alpine-setup.sh
│       ├── arch-setup.sh
│       ├── gentoo-setup.sh
│       ├── void-setup.sh
│       └── freebsd-setup.sh
├── backup/
│   ├── restic-config.conf
│   ├── backup.sh
│   ├── com.user.restic-backup.plist
│   ├── restic-backup.service
│   ├── restic-backup.timer
│   └── quick-test.sh
└── tests/
    ├── run-tests.sh
    ├── quick-validate.sh
    ├── unit/
    ├── integration/
    └── e2e/
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
- **Security**: pass/gopass, gnupg, ssh-agent, git-crypt
- **Sync**: syncthing
- **Backup**: restic
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
- gnupg, openssh, git-crypt
- syncthing

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
- pass, restic, python3, rustup, gh
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
Users can create custom profiles in `profiles/*.conf`:
- Inherit from `minimal` or `full`
- Add extra packages, dotfiles, services
- Define setup scripts

Example profiles included:
- `server.conf.example`: minimal + monitoring + networking
- `gaming.conf.example`: full + gaming tools

---

## Setup Process

### Initial Setup
```bash
# Option 1: Clone and run
git clone https://github.com/yourusername/machine-setup.git
cd machine-setup
./setup.sh

# Option 2: Run standalone (auto-clones repo)
curl -fsSL https://raw.githubusercontent.com/yourusername/machine-setup/main/setup.sh | bash

# Specify profile explicitly
./setup.sh --profile minimal
./setup.sh --profile full
```

### Setup Steps
1. **Bootstrap** (clone repo if not present locally)
2. **Detect platform** (macOS, FreeBSD, Fedora, Ubuntu, Gentoo, Void, RaspberryPiOS, Windows)
3. **Load profile** (auto-detect or via --profile flag)
4. **Resolve profile inheritance** (e.g., full extends minimal)
5. **Install packages** from profile + platform packages
6. **Symlink dotfiles** from `dotfiles/profiles/<profile>/`
7. **Setup Syncthing** (configure and connect devices)
8. **Setup backup** (Restic + daily cron/systemd/launchd)
9. **Unlock git-crypt** (requires GPG key)
10. **Enable services** (sshd, docker, etc.)
11. **Run setup scripts** (ssh-agent, docker, etc.)
12. **Verify installation**

---

## Package Management

### Platform Detection
Auto-detect OS and map to package manager:
- Fedora/Rocky/Alma → dnf
- Ubuntu/RaspberryPiOS/Debian → apt
- Gentoo → emerge
- Void → xbps
- Arch/Manjaro → pacman
- Alpine → apk
- OpenSUSE → zypper
- macOS → Homebrew
- FreeBSD → pkg
- Windows → winget

### Package Name Mapping
Some tools have different names across platforms (defined in `packages/common.conf`):
```ini
[package_mapping.fd-find]
ubuntu = fd-find
fedora = fd-find
debian = fd-find
void = fd
gentoo = sys-apps/fd
freebsd = fd-find
macos = fd
windows = fd.find
```

### Gentoo Special Handling
- Enable `binpkg` by default for faster installs
- User-defined global `USE` flags in `gentoo.conf`
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

### Arch Linux Special Handling
- Use `pacman` package manager
- Support AUR packages via `yay` helper
- Parallel downloads enabled by default
- Package signing with `pacman-key`
- Support for Arch derivatives (Manjaro, EndeavourOS, Garuda)

### Alpine Linux Special Handling
- Use `apk` package manager
- OpenRC init system (not systemd)
- Musl libc (not glibc)
- Minimal base system
- Community and testing repositories

### Debian Special Handling
- Stable/Testing/Unstable branches
- Backports repository support
- Similar to Ubuntu but different release cycle
- EPEL-like additional repositories

### OpenSUSE Special Handling
- Use `zypper` package manager
- Patterns for package groups
- Tumbleweed (rolling) and Leap (stable) support
- OBS (Open Build Service) repositories

### Rocky/Alma Linux Special Handling
- RHEL-compatible distributions
- Use `dnf` package manager
- EPEL repository support
- Binary compatible with RHEL

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
```ini
[repository]
location = b2:your-bucket-name:machine-backup
password = <from-password-manager>

[backup]
schedule = daily

[retention]
keep_daily = 7
keep_weekly = 4
keep_monthly = 12

[paths]
1 = ~/dotfiles
2 = ~/.ssh
3 = ~/Documents
4 = ~/Projects

[excludes]
1 = node_modules
2 = .git/objects
3 = *.log
```

### Backup Targets
- Primary: BackBlaze B2 (default)
- Alternative: Any S3-compatible service

### Backup Script
Runs daily at 2 AM via cron/systemd timer/launchd.

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
- Linux (systemd): systemd timers
- Linux (OpenRC): cron + rc-service
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
- Quick start guide (including standalone bootstrap)
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

- Single command setup on any supported platform
- Standalone bootstrap (works without pre-cloning the repo)
- Minimal profile < 20 packages, full profile < 50 packages
- Real-time dotfiles sync across all machines
- Secrets encrypted at rest and in transit
- Daily automated backups with < 1 hour completion time
- Restore procedure completes in < 30 minutes
- Profile switching works without re-installing base tools
- All platforms tested and documented
