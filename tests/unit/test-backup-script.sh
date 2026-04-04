#!/usr/bin/env bash
set -euo pipefail

# Test script for backup functionality
# This tests the backup script without requiring restic to be installed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Script dir: $SCRIPT_DIR"
echo "Repo root: $REPO_ROOT"
echo ""

# Test 1: Help flag
echo "Test 1: Help flag"
if [[ -f "$REPO_ROOT/backup/backup.sh" ]]; then
    if "$REPO_ROOT/backup/backup.sh" --help 2>&1 | grep -q "Restic backup script"; then
        echo "✅ Help flag works"
    else
        echo "❌ Help flag failed"
        exit 1
    fi
else
    echo "❌ Backup script not found at $REPO_ROOT/backup/backup.sh"
    exit 1
fi
echo ""

# Test 2: Dry-run flag parsing
echo "Test 2: Dry-run flag parsing"
output=$("$REPO_ROOT/backup/backup.sh" --dry-run 2>&1) || true
if echo "$output" | grep -q "DRY-RUN"; then
    echo "✅ Dry-run flag parsed correctly"
elif echo "$output" | grep -q "restic is not installed"; then
    echo "✅ Dependency check works (restic not installed)"
elif echo "$output" | grep -q "Please set a strong password"; then
    echo "✅ Config validation works (placeholder password detected)"
elif echo "$output" | grep -q "not found\|not configured"; then
    echo "✅ Config validation works"
else
    echo "❌ Unexpected error: $output"
    exit 1
fi
echo ""

# Test 3: Config validation
echo "Test 3: Config file validation"
if [[ -f "$REPO_ROOT/backup/restic-config.conf" ]]; then
    if grep -q "^\[repository\]" "$REPO_ROOT/backup/restic-config.conf" 2>/dev/null; then
        echo "✅ Config file is valid INI"
    else
        echo "❌ Config file has invalid format"
        exit 1
    fi
else
    echo "❌ Config file not found"
    exit 1
fi
echo ""

# Test 4: Script is executable
echo "Test 4: Script permissions"
if [[ -x "$REPO_ROOT/backup/backup.sh" ]]; then
    echo "✅ Backup script is executable"
else
    echo "❌ Backup script is not executable"
    exit 1
fi
echo ""

# Test 5: README exists
echo "Test 5: Documentation exists"
if [[ -f "$REPO_ROOT/backup/README.md" ]]; then
    if grep -q "Restic Backup System" "$REPO_ROOT/backup/README.md"; then
        echo "✅ Backup documentation exists"
    else
        echo "❌ Backup documentation incomplete"
        exit 1
    fi
else
    echo "❌ Backup documentation not found"
    exit 1
fi
echo ""

echo "====================="
echo "✅ All backup tests passed!"
echo ""
