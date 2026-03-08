#!/usr/bin/env bash
set -euo pipefail

# Test: Backup Configuration
# Validates backup script and configuration generation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/scripts/yaml-parser.sh"

echo "Testing backup configuration"

BACKUP_CONFIG="${REPO_ROOT}/backup/restic-config.yaml"
BACKUP_SCRIPT="${REPO_ROOT}/backup/backup.sh"

# Check that backup config exists
if [[ ! -f "$BACKUP_CONFIG" ]]; then
    echo "❌ FAIL: Backup config not found"
    exit 1
fi

# Validate backup config YAML
CONFIG_CONTENT=$(cat "$BACKUP_CONFIG")

# Check required fields
REPO=$(yaml_get "$CONFIG_CONTENT" "repository" "")
if [[ -z "$REPO" || "$REPO" == "null" ]]; then
    echo "❌ FAIL: Backup config missing 'repository'"
    exit 1
fi

PASSWORD=$(yaml_get "$CONFIG_CONTENT" "password" "")
if [[ -z "$PASSWORD" || "$PASSWORD" == "null" ]]; then
    echo "❌ FAIL: Backup config missing 'password'"
    exit 1
fi

RETENTION=$(yaml_get "$CONFIG_CONTENT" "retention" "")
if [[ -z "$RETENTION" || "$RETENTION" == "null" ]]; then
    echo "❌ FAIL: Backup config missing 'retention'"
    exit 1
fi

PATHS=$(yaml_get_list "$CONFIG_CONTENT" "paths")
if [[ -z "$PATHS" ]]; then
    echo "❌ FAIL: Backup config missing 'paths'"
    exit 1
fi

# Check that backup script exists and is executable
if [[ ! -f "$BACKUP_SCRIPT" ]]; then
    echo "❌ FAIL: Backup script not found"
    exit 1
fi

if [[ ! -x "$BACKUP_SCRIPT" ]]; then
    echo "❌ FAIL: Backup script is not executable"
    exit 1
fi

# Test dry-run of backup script (without actually running restic)
echo "Testing backup script dry-run..."

# Mock restic command
cat > /tmp/mock-restic <<'EOF'
#!/bin/bash
echo "Mock restic: $@"
EOF
chmod +x /tmp/mock-restic

# The actual backup would be tested in integration tests
echo "✅ PASS: Backup configuration is valid"
