# Machine Setup

Cross-platform machine configuration and syncing system with profile-based package management, dotfiles synchronization, and automated backups.

## Features

- **Cross-Platform Support**: Fedora, Ubuntu, Debian, Gentoo, Void, Arch, Alpine, OpenSUSE, Rocky, Alma, RaspberryPiOS, macOS, FreeBSD, Windows 11
- **Profile System**: Minimal, full, or custom configurations
- **Dotfiles Sync**: Real-time synchronization via Syncthing
- **Secrets Management**: Encrypted secrets with git-crypt
- **Automated Backups**: Daily encrypted backups with Restic to BackBlaze B2 or S3
- **Package Management**: Unified INI-based package definitions

## Quick Start

```bash
# Option 1: Clone and run
git clone https://github.com/yourusername/machine-setup.git
cd machine-setup
./setup.sh

# Option 2: Run standalone (auto-clones repo to ~/.machine-setup)
curl -fsSL https://raw.githubusercontent.com/yourusername/machine-setup/main/setup.sh | bash

# Or specify a profile explicitly
./setup.sh --profile minimal
./setup.sh --profile full
```

## Supported Platforms

| Platform | Package Manager | Default Profile |
|----------|----------------|-----------------|
| Fedora | dnf | full |
| Ubuntu | apt | full |
| Debian | apt | full |
| Gentoo | emerge | full |
| Void Linux | xbps | full |
| Arch Linux | pacman | full |
| Alpine Linux | apk | full |
| OpenSUSE | zypper | full |
| Rocky Linux | dnf | full |
| AlmaLinux | dnf | full |
| RaspberryPiOS | apt | minimal |
| macOS | Homebrew | full |
| FreeBSD | pkg + ports | full |
| Windows 11 | winget | full |

## Profiles

### Minimal Profile
Essential CLI tools only - ideal for servers and resource-constrained systems.

**Includes:**
- Shell: nushell
- Editor: neovim (basic config)
- Tools: ripgrep, fd-find, fzf, git, mise, gnupg, openssh, git-crypt
- Sync: syncthing

**Use for:** Servers, Raspberry Pi, resource-constrained systems

### Full Profile
Complete development environment with all tools and utilities.

**Includes:**
- Everything in minimal plus:
- Multiplexer: zellij
- Modern CLI: bat, eza, dust, bottom, procs
- Utilities: jq, httpie, doggo, gping, rsync, yazi, ouch, asciinema, glow
- Languages: Python 3, Rust (via mise)
- DevOps: Docker, kubectl
- Backup: restic

**Use for:** Development workstations

### Custom Profiles
Create your own profiles in `profiles/` directory:

```ini
; profiles/my-custom.conf
[profile]
name = my-custom
description = My custom setup
extends = minimal

[packages]
extra = my-favorite-tool
extra = another-tool

[dotfiles]
source = profiles/custom/

[dotfiles.links.1]
src = .config/myapp/
dest = ~/.config/myapp/

[services]
enable = myservice

[setup_scripts]
run = scripts/setup-myapp.sh
```

Then run:
```bash
./setup.sh --profile my-custom
```

## Usage

### Basic Commands

```bash
# Auto-detect and setup
./setup.sh

# Use specific profile
./setup.sh --profile minimal

# Skip certain steps
./setup.sh --no-packages
./setup.sh --no-dotfiles
./setup.sh --no-syncthing
./setup.sh --no-backup

# Dry run (show what would be done)
./setup.sh --dry-run

# List available profiles
./setup.sh --list-profiles

# Show profile details
./setup.sh --show-profile full
```

### Individual Scripts

```bash
# Install packages only
./scripts/install-packages.sh --profile full

# Link dotfiles only
./scripts/link-dotfiles.sh --profile minimal

# Setup Syncthing
./scripts/setup-syncthing.sh

# Setup backup
./scripts/setup-backup.sh
```

## Directory Structure

```
machine-setup/
├── setup.sh                   # Main setup script
├── packages/                  # Package definitions
│   ├── common.conf           # Universal packages
│   ├── platforms/            # Platform-specific packages
│   └── custom.conf.example   # Custom package template
├── profiles/                  # Profile definitions
│   ├── minimal.conf
│   ├── full.conf
│   └── *.example             # Example custom profiles
├── dotfiles/                  # Configuration files
│   ├── profiles/             # Profile-specific dotfiles
│   └── .gitattributes        # git-crypt config
├── scripts/                   # Setup scripts
│   └── utils/                # Platform-specific helpers
├── backup/                    # Backup configuration
└── tests/                     # Test suite
```

## Dotfiles Management

### Structure

Dotfiles are organized by profile:
```
dotfiles/
├── profiles/
│   ├── minimal/       # Minimal profile dotfiles
│   │   ├── .config/
│   │   │   ├── nushell/
│   │   │   └── nvim/
│   │   ├── .gitconfig
│   │   └── .ssh/
│   └── full/          # Full profile dotfiles
│       ├── shell/
│       ├── editors/
│       ├── multiplexer/
│       └── ...
```

### Syncthing Setup

1. Run the Syncthing setup script:
   ```bash
   ./scripts/setup-syncthing.sh
   ```

2. Start Syncthing:
   ```bash
   syncthing
   ```

3. Open the web UI: http://localhost:8384

4. Configure devices and folders:
   - Add the `~/dotfiles` folder
   - Connect to other devices using Device IDs
   - Enable encryption for security

5. (Optional) Enable Syncthing as a service:
   - The setup script will prompt you

## Secrets Management

### git-crypt Setup

1. Install git-crypt:
   ```bash
   # Fedora/Ubuntu
   sudo dnf install git-crypt  # or apt install git-crypt
   
   # macOS
   brew install git-crypt
   ```

2. Initialize git-crypt in the dotfiles repo:
   ```bash
   cd dotfiles/
   git-crypt init
   ```

3. Add your GPG key:
   ```bash
   git-crypt add-gpg-user YOUR_GPG_KEY_ID
   ```

4. Add secrets to the `secrets/` directory:
   ```bash
   mkdir -p secrets/ssh-keys
   cp ~/.ssh/id_ed25519 secrets/ssh-keys/
   git add secrets/
   git commit -m "Add encrypted SSH keys"
   ```

5. On new machines, unlock the repository:
   ```bash
   git-crypt unlock
   ```

### Encrypted Files

The following are automatically encrypted:
- `secrets/**` - All secrets
- `**/.ssh/id_*` - SSH private keys
- `**/*.gpg` - GPG keys
- `**/api-tokens/**` - API tokens
- `**/.env*` - Environment files
- `backup/restic-config.conf` - Backup credentials

## Backup Strategy

### Restic to BackBlaze B2

1. Setup backup:
   ```bash
   ./scripts/setup-backup.sh
   ```

2. Edit `backup/restic-config.conf` with your credentials:
   ```ini
   [repository]
   location = b2:your-bucket-name:machine-backup
   password = your-strong-password

   [b2]
   account_id = your-account-id
   account_key = your-account-key
   ```

3. Test the backup:
   ```bash
   ./backup/backup.sh --dry-run
   ```

4. Run initial backup:
   ```bash
   ./backup/backup.sh
   ```

5. Automated daily backups will be configured automatically

### Restore

```bash
# List snapshots
restic snapshots

# Restore specific snapshot
restic restore <snapshot-id> --target /tmp/restore

# Restore specific files
restic restore <snapshot-id> --target /tmp/restore --include /path/to/file
```

## Package Management

### Adding Packages

Edit `packages/custom.conf`:
```ini
[packages]
extra = my-new-tool another-package
```

Then run:
```bash
./setup.sh --profile full --no-dotfiles
```

### Platform-Specific Packages

Each platform has its own package file in `packages/platforms/`:
- `macos.conf`
- `fedora.conf`
- `ubuntu.conf`
- `debian.conf`
- `gentoo.conf`
- `void.conf`
- `arch.conf`
- `alpine.conf`
- `opensuse.conf`
- `rocky.conf`
- `alma.conf`
- `freebsd.conf`
- `raspberrypios.conf`
- `windows.conf`

## Customization

### Creating Custom Profiles

1. Create a new profile file:
   ```bash
   cp profiles/server.conf.example profiles/my-server.conf
   ```

2. Edit the profile:
   ```ini
   [profile]
   name = my-server
   description = My custom server setup
   extends = minimal

   [packages]
   monitoring = prometheus-node-exporter grafana

   [services]
   enable = prometheus-node-exporter
   ```

3. Run with your profile:
   ```bash
   ./setup.sh --profile my-server
   ```

### Platform-Specific Setup

For platform-specific customizations, edit the appropriate file:
- `scripts/utils/gentoo-setup.sh`
- `scripts/utils/void-setup.sh`
- `scripts/utils/freebsd-setup.sh`

## Security Best Practices

- **GPG Signing**: Git commits are signed by default
- **SSH Keys**: Ed25519 keys recommended
- **Secrets**: Never commit unencrypted secrets
- **Backups**: Encrypted with strong password
- **Syncthing**: Use TLS and password-protected GUI

## Troubleshooting

### Configuration Format
This project uses **INI format** for all configuration files (no external dependencies required).

```ini
# Example: profiles/minimal.conf
[profile]
name = minimal
description = Essential CLI tools only
extends = false

[packages]
shell = nushell
editors = neovim
cli_essential = ripgrep fd-find fzf
```

### git-crypt unlock fails
```bash
# Ensure your GPG key is imported
gpg --import your-key.asc

# Trust the key
gpg --edit-key YOUR_KEY_ID
> trust
> 5
> save
```

### Syncthing not syncing
1. Check both devices are online
2. Verify Device IDs are correct
3. Check firewall allows port 22000
4. Ensure folder is shared between devices

### Backup fails
1. Verify credentials in `backup/restic-config.conf`
2. Check repository exists (create with `restic init` if needed)
3. Ensure password is correct
4. Check network connectivity to B2/S3

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - See LICENSE file for details

## Acknowledgments

- [Syncthing](https://syncthing.net/) for dotfiles synchronization
- [Restic](https://restic.net/) for backups
- [git-crypt](https://www.agwa.name/projects/git-crypt/) for secrets encryption
- [mise](https://github.com/jdx/mise) for runtime management
