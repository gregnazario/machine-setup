#!/usr/bin/env bash
set -euo pipefail

# Backup System Documentation
# This document explains how to use the backup system

cat <<'EOF'
# Restic Backup System

## Overview

This backup system uses Restic to create encrypted, deduplicated backups to:
- BackBlaze B2 (recommended)
- Any S3-compatible storage

## Quick Start

1. Configure your credentials in `backup/restic-config.conf`:

   ```bash
   cd backup
   cp restic-config.conf restic-config.conf.backup
   vi restic-config.conf
   ```

2. Set required fields:
   - `repository`: Your backup repository location
   - `password`: Strong encryption password (SAVE THIS!)
   - `paths`: Directories to backup
   - `b2.account_id` and `b2.account_key` (if using B2)
   - `s3.access_key` and `s3.secret_key` (if using S3)

3. Test with dry-run:

   ```bash
   ./backup/backup.sh --dry-run
   ```

4. Run your first backup:

   ```bash
   ./backup/backup.sh
   ```

## Command Line Options

```bash
./backup/backup.sh [OPTIONS]

Options:
    -n, --dry-run          Preview backup without running
    -v, --verbose          Show detailed output
    -c, --check            Verify backup integrity after creation
    -l, --list             List available snapshots
    -h, --help             Show help message
```

## Examples

### Preview Backup (Dry Run)
```bash
./backup/backup.sh --dry-run
```

### Run Backup with Verification
```bash
./backup/backup.sh --check --verbose
```

### List Snapshots
```bash
./backup/backup.sh --list
```

## Automated Backups

### Option 1: Cron (All Platforms)

Add to crontab:
```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/machine-setup/backup/backup.sh >> ~/backup.log 2>&1
```

### Option 2: Systemd Timer (Linux with systemd)

1. Create systemd service:
   ```bash
   sudo tee /etc/systemd/system/restic-backup.service > /dev/null <<EOL
   [Unit]
   Description=Restic Backup
   After=network.target

   [Service]
   Type=oneshot
   ExecStart=/path/to/machine-setup/backup/backup.sh
   User=YOUR_USERNAME

   [Install]
   WantedBy=multi-user.target
   EOL
   ```

2. Create systemd timer:
   ```bash
   sudo tee /etc/systemd/system/restic-backup.timer > /dev/null <<EOL
   [Unit]
   Description=Run Restic Backup Daily

   [Timer]
   OnCalendar=daily
   Persistent=true

   [Install]
   WantedBy=timers.target
   EOL
   ```

3. Enable timer:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable restic-backup.timer
   sudo systemctl start restic-backup.timer
   ```

4. Check timer status:
   ```bash
   systemctl list-timers restic-backup.timer
   ```

### Option 3: launchd (macOS)

1. Create plist:
   ```bash
   tee ~/Library/LaunchAgents/com.user.restic-backup.plist > /dev/null <<EOL
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>Label</key>
       <string>com.user.restic-backup</string>
       <key>ProgramArguments</key>
       <array>
           <string>/path/to/machine-setup/backup/backup.sh</string>
       </array>
       <key>StartCalendarInterval</key>
       <dict>
           <key>Hour</key>
           <integer>2</integer>
           <key>Minute</key>
           <integer>0</integer>
       </dict>
       <key>StandardOutPath</key>
       <string>/tmp/restic-backup.log</string>
       <key>StandardErrorPath</key>
       <string>/tmp/restic-backup.log</string>
   </dict>
   </plist>
   EOL
   ```

2. Load the agent:
   ```bash
   launchctl load ~/Library/LaunchAgents/com.user.restic-backup.plist
   ```

## Restoring from Backup

### List Snapshots
```bash
export RESTIC_PASSWORD="your-password"
export B2_ACCOUNT_ID="your-id"
export B2_ACCOUNT_KEY="your-key"
restic -r b2:bucket:path snapshots
```

### Restore Entire Backup
```bash
restic -r b2:bucket:path restore latest --target /tmp/restore
```

### Restore Specific Files
```bash
restic -r b2:bucket:path restore latest --target /tmp/restore --include /path/to/file
```

### Mount Repository
```bash
restic -r b2:bucket:path mount /mnt/restic
# Browse files in /mnt/restic
# Unmount with: fusermount -u /mnt/restic
```

## Configuration Reference

### Required Fields

```ini
[repository]
location = b2:your-bucket:machine-backup
password = strong-encryption-password

[paths]
1 = ~/Documents
2 = ~/Projects
```

### Retention Policy

```ini
[retention]
keep_daily = 7      # Keep 7 daily backups
keep_weekly = 4     # Keep 4 weekly backups
keep_monthly = 12   # Keep 12 monthly backups
keep_yearly = 2     # Keep 2 yearly backups
```

### Excludes

```ini
[excludes]
1 = node_modules     # Exclude by name
2 = *.log            # Exclude by pattern
3 = .cache           # Exclude cache directories
```

### BackBlaze B2

```ini
[repository]
location = b2:your-bucket-name:backup-path

[b2]
account_id = your-account-id
account_key = your-account-key
```

### S3-Compatible Storage

```ini
[repository]
location = s3:https://s3.example.com/bucket/backup-path

[s3]
access_key = your-access-key
secret_key = your-secret-key
region = us-east-1  # Optional
```

## Security Notes

1. **Password**: Use a strong, unique password. Store it safely!
2. **Encryption**: All backups are encrypted with AES-256
3. **git-crypt**: The config file should be encrypted with git-crypt
4. **Credentials**: Never commit credentials to git in plain text

## Monitoring

### Check Logs
```bash
tail -f ~/backup.log
```

### Verify Backups
```bash
./backup/backup.sh --check
```

### Notifications

The script supports desktop notifications via `notify-send` (Linux).
For email notifications, you can add a mail command to the script.

## Troubleshooting

### Repository Already Initialized
If you see "repository already initialized", this is normal. The script checks this.

### Permission Denied
Ensure the backup script is executable:
```bash
chmod +x backup/backup.sh
```

### Path Not Found
Verify paths in `restic-config.conf` exist. Non-existent paths are skipped with a warning.

### B2/S3 Connection Failed
- Verify your credentials are correct
- Check network connectivity
- Ensure bucket exists and is accessible

### Backup Too Slow
- Add more excludes to skip unnecessary files
- Use `--verbose` to see what's being backed up
- Consider splitting into multiple repositories

## Best Practices

1. **Test Restores**: Periodically test restoring files
2. **Monitor Logs**: Check backup.log regularly
3. **Secure Password**: Store your password in a password manager
4. **Multiple Locations**: Consider backing up to multiple backends
5. **Regular Backups**: Schedule daily automated backups
6. **Verify Integrity**: Run with `--check` weekly
7. **Monitor Space**: Check repository size periodically

## Advanced Usage

### Exclude File
Create a file with exclude patterns:
```bash
# Create .backup-excludes
node_modules
*.log
.cache
target/
build/
```

### Multiple Repositories
Create separate config files:
```bash
backup/
├── restic-config.conf       # Main backup
├── restic-config-media.conf # Media backup
└── restic-config-code.conf  # Code backup
```

### Pre/Post Scripts
Add hooks in the backup script:
```bash
# Before backup
echo "Starting backup at $(date)"

# After backup
echo "Backup completed at $(date)"
```

## Resources

- [Restic Documentation](https://restic.readthedocs.io/)
- [BackBlaze B2](https://www.backblaze.com/b2/)
- [Restic Forum](https://forum.restic.net/)

EOF
