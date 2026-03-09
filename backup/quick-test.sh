#!/bin/bash
# Quick Backup Example
# This script demonstrates how to use the backup system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${REPO_ROOT}/scripts/ini-parser.sh"

echo "==================================="
echo "Restic Backup Quick Example"
echo "==================================="
echo ""

# Check if restic is installed
if ! command -v restic &> /dev/null; then
    echo "⚠️  Restic is not installed"
    echo ""
    echo "Install on Fedora/Rocky/Alma:"
    echo "  sudo dnf install restic"
    echo ""
    echo "Install on Ubuntu/Debian:"
    echo "  sudo apt install restic"
    echo ""
    echo "Install on Arch:"
    echo "  sudo pacman -S restic"
    echo ""
    echo "Install on macOS:"
    echo "  brew install restic"
    echo ""
    exit 1
fi

echo "✅ Restic is installed: $(restic version)"
echo ""

# Check configuration
CONFIG_FILE="backup/restic-config.conf"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    echo ""
    echo "Please create a configuration file first."
    exit 1
fi

echo "✅ Configuration file found"
echo ""

# Check if password is set
PASSWORD=$(ini_get "$CONFIG_FILE" "repository" "password" "")
if [[ "$PASSWORD" == "CHANGE_ME_STRONG_PASSWORD" || -z "$PASSWORD" ]]; then
    echo "⚠️  Please set a strong password in $CONFIG_FILE"
    echo ""
    echo "Edit the file and update:"
    echo "  [repository]"
    echo "  password = your-strong-password-here"
    echo ""
    exit 1
fi

echo "✅ Password is configured"
echo ""

# Check if repository is set
REPOSITORY=$(ini_get "$CONFIG_FILE" "repository" "location" "")
if [[ -z "$REPOSITORY" || "$REPOSITORY" == "null" ]]; then
    echo "⚠️  Please configure your repository in $CONFIG_FILE"
    echo ""
    echo "For BackBlaze B2:"
    echo "  [repository]"
    echo "  location = b2:your-bucket-name:machine-backup"
    echo ""
    echo "For S3:"
    echo "  [repository]"
    echo "  location = s3:https://s3.example.com/bucket/backup"
    echo ""
    exit 1
fi

echo "✅ Repository is configured: $REPOSITORY"
echo ""

# Check credentials based on repository type
if [[ "$REPOSITORY" == b2:* ]]; then
    B2_ID=$(ini_get "$CONFIG_FILE" "b2" "account_id" "")
    if [[ "$B2_ID" == "YOUR_B2_ACCOUNT_ID" || -z "$B2_ID" ]]; then
        echo "⚠️  Please configure B2 credentials in $CONFIG_FILE"
        echo ""
        echo "  [b2]"
        echo "  account_id = your-account-id"
        echo "  account_key = your-account-key"
        echo ""
        exit 1
    fi
    echo "✅ B2 credentials are configured"
    echo ""
elif [[ "$REPOSITORY" == s3:* ]]; then
    S3_KEY=$(ini_get "$CONFIG_FILE" "s3" "access_key" "")
    if [[ "$S3_KEY" == "YOUR_S3_ACCESS_KEY" || -z "$S3_KEY" ]]; then
        echo "⚠️  Please configure S3 credentials in $CONFIG_FILE"
        echo ""
        echo "  [s3]"
        echo "  access_key = your-access-key"
        echo "  secret_key = your-secret-key"
        echo ""
        exit 1
    fi
    echo "✅ S3 credentials are configured"
    echo ""
fi

# Everything looks good, run dry-run
echo "==================================="
echo "Running Dry-Run Test"
echo "==================================="
echo ""

./backup/backup.sh --dry-run

echo ""
echo "==================================="
echo "✅ Dry-run completed successfully!"
echo "==================================="
echo ""
echo "Next steps:"
echo "  1. Review the dry-run output above"
echo "  2. If everything looks good, run:"
echo "     ./backup/backup.sh"
echo ""
echo "  3. To set up automated daily backups, see:"
echo "     backup/README.md"
echo ""
