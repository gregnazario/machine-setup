# Platform Utility Scripts

This directory contains platform-specific setup scripts for advanced configuration that goes beyond basic package installation.

## Overview

These scripts handle platform-specific configurations that cannot be done through the standard package management system, such as:
- Package manager configuration and optimization
- System service configuration
- Platform-specific tools and utilities
- System tuning and optimization

## Available Scripts

### Linux Distributions

#### Gentoo Linux (`gentoo-setup.sh`)
Configures Portage, USE flags, and binary package support.

**What it does:**
- Enables binary package support (binpkg)
- Configures global and package-specific USE flags
- Creates Portage directories
- Sets up package keywords
- Optimizes make.conf

**Usage:**
```bash
sudo ./scripts/utils/gentoo-setup.sh
sudo ./scripts/utils/gentoo-setup.sh --dry-run
sudo ./scripts/utils/gentoo-setup.sh --sync --update
```

#### Void Linux (`void-setup.sh`)
Configures XBPS repositories and runit services.

**What it does:**
- Enables nonfree and multilib repositories
- Configures XBPS settings
- Enables runit services (sshd, docker, syncthing, cronie)
- Configures locale and timezone

**Usage:**
```bash
sudo ./scripts/utils/void-setup.sh
sudo ./scripts/utils/void-setup.sh --dry-run
sudo ./scripts/utils/void-setup.sh --update
```

#### Arch Linux (`arch-setup.sh`)
Configures pacman, AUR helper, and system optimizations.

**What it does:**
- Optimizes pacman configuration
- Installs yay (AUR helper)
- Configures makepkg for parallel compilation
- Sets up pacman hooks
- Configures reflector for mirror management

**Usage:**
```bash
sudo ./scripts/utils/arch-setup.sh
sudo ./scripts/utils/arch-setup.sh --dry-run
sudo ./scripts/utils/arch-setup.sh --update
```

#### Alpine Linux (`alpine-setup.sh`)
Configures APK and OpenRC services.

**What it does:**
- Configures APK repositories
- Sets up APK cache
- Configures OpenRC services
- Sets up networking with NetworkManager
- Configures bash and sudo

**Usage:**
```bash
sudo ./scripts/utils/alpine-setup.sh
sudo ./scripts/utils/alpine-setup.sh --dry-run
sudo ./scripts/utils/alpine-setup.sh --update
```

### BSD Systems

#### FreeBSD (`freebsd-setup.sh`)
Configures pkg, ports, and ZFS settings.

**What it does:**
- Initializes and configures pkg
- Sets up ports collection
- Configures make.conf
- Checks and configures ZFS support
- Configures rc.conf and sysctl
- Installs FreeBSD-specific tools

**Usage:**
```bash
sudo ./scripts/utils/freebsd-setup.sh
sudo ./scripts/utils/freebsd-setup.sh --dry-run
sudo ./scripts/utils/freebsd-setup.sh --update
```

## Common Options

All scripts support the following options:

- `-n, --dry-run` - Preview changes without executing
- `-u, --update` - Update system after configuration
- `-h, --help` - Show help message

## When to Use These Scripts

### Initial Setup
Run the appropriate script after installing a fresh system but before running `./setup.sh`:

```bash
# Example for Arch Linux
sudo ./scripts/utils/arch-setup.sh
./setup.sh --profile full
```

### Post-Installation
You can also run these scripts after the main setup to apply platform-specific optimizations:

```bash
# Example for Void Linux
./setup.sh --profile full
sudo ./scripts/utils/void-setup.sh
```

### Troubleshooting
Use `--dry-run` to preview what changes will be made:

```bash
sudo ./scripts/utils/gentoo-setup.sh --dry-run
```

## Platform-Specific Notes

### Gentoo
- Must be run as root
- Creates backups of make.conf before modifying
- Configures binary packages for faster installs
- Sets up sensible default USE flags

### Void
- Must be run as root
- Enables nonfree and multilib repos automatically
- Uses runit for service management
- Configures XBPS for optimal performance

### Arch
- Must be run as root
- Installs yay from AUR (builds from source)
- Optimizes makepkg for parallel compilation
- Sets up automatic mirror updates with reflector

### Alpine
- Must be run as root
- Uses OpenRC for service management (not systemd)
- Configures community repository
- Sets up networking with NetworkManager

### FreeBSD
- Must be run as root
- Initializes pkg if not already done
- Optional ports collection setup
- ZFS detection and configuration
- Uses rc.conf for service management

## Testing

Each script includes dry-run mode for safe testing:

```bash
# Test without making changes
sudo ./scripts/utils/[platform]-setup.sh --dry-run
```

## Integration with Main Setup

These scripts are automatically called by the main setup process when needed:

```bash
# Main setup calls platform utils automatically
./setup.sh --profile full
```

You can also run them independently for manual configuration.

## Adding New Platform Scripts

To add support for a new platform:

1. Create `[platform]-setup.sh` in this directory
2. Follow the same structure as existing scripts
3. Include functions for:
   - Platform detection
   - Package manager configuration
   - Service management
   - System tuning
4. Add dry-run support
5. Add help documentation
6. Make executable: `chmod +x scripts/utils/[platform]-setup.sh`

## Error Handling

All scripts include:
- Root permission checks
- Platform verification
- Backup creation before modifying config files
- Detailed logging
- Dry-run mode for safe testing

## Logs and Backups

Configuration file backups are created automatically:
- Format: `[file].backup.YYYYMMDD_HHMMSS`
- Location: Same directory as original file

Example:
```bash
/etc/portage/make.conf.backup.20260307_123456
```

## Troubleshooting

### Permission Denied
All scripts must be run as root:
```bash
sudo ./scripts/utils/[platform]-setup.sh
```

### Platform Not Detected
Ensure you're running the correct script for your platform:
```bash
cat /etc/os-release  # Check your distribution
```

### Dry-Run Mode
Always test with dry-run first:
```bash
sudo ./scripts/utils/[platform]-setup.sh --dry-run
```

### Service Issues
Check service status after configuration:
```bash
# systemd (Fedora, Arch, Debian, etc.)
systemctl status [service]

# runit (Void)
sv status /var/service/[service]

# OpenRC (Alpine, Gentoo)
rc-status
rc-service [service] status

# rc.d (FreeBSD)
service [service] status
```

## Contributing

When adding new platform scripts:
1. Follow existing code structure
2. Include comprehensive logging
3. Add dry-run support
4. Create backups before modifying files
5. Test thoroughly
6. Update this README

## See Also

- [Main Setup Script](../../setup.sh)
- [Package Configuration](../../packages/)
- [Platform Detection](../platform-detect.sh)
- [Package Installation](../install-packages.sh)
