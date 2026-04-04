#!/usr/bin/env bash
set -euo pipefail

# Integration Test: Ubuntu Setup
# Tests the complete setup process on Ubuntu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Running Ubuntu integration test"

# Create isolated test environment
TEST_HOME="/tmp/test-ubuntu-setup"
rm -rf "$TEST_HOME"
mkdir -p "$TEST_HOME"

# Mock home directory
export HOME="$TEST_HOME"

cd "$REPO_ROOT"

# Skip if not running on Ubuntu/Debian
source scripts/platform-detect.sh
detect_platform
if [[ "$PLATFORM" != "ubuntu" && "$PLATFORM" != "debian" ]]; then
    echo "⏭️  SKIP: Not running on Ubuntu/Debian (detected: $PLATFORM)"
    exit 0
fi

# Test platform detection
echo "Testing platform detection..."

if [[ "$PLATFORM" != "ubuntu" ]]; then
    echo "❌ FAIL: Platform should be 'ubuntu', got '$PLATFORM'"
    exit 1
fi

if [[ "$PACKAGE_MANAGER" != "apt" ]]; then
    echo "❌ FAIL: Package manager should be 'apt', got '$PACKAGE_MANAGER'"
    exit 1
fi

echo "✅ Platform detection: Ubuntu with apt"

# Test profile loading
echo "Testing profile loading..."
source scripts/profile-loader.sh
load_profile "minimal"

if [[ "$PROFILE_NAME" != "minimal" ]]; then
    echo "❌ FAIL: Profile should be 'minimal', got '$PROFILE_NAME'"
    exit 1
fi

echo "✅ Profile loading: minimal"

# Test package collection
echo "Testing package collection..."
source scripts/install-packages.sh
PACKAGES=$(collect_packages)

if [[ -z "$PACKAGES" ]]; then
    echo "❌ FAIL: No packages collected"
    exit 1
fi

if ! echo "$PACKAGES" | grep -q "git"; then
    echo "❌ FAIL: Essential package 'git' not in collection"
    exit 1
fi

echo "✅ Package collection: $(echo "$PACKAGES" | wc -w) packages"

# Test dry-run setup
echo "Testing dry-run setup..."
if ! ./setup.sh --dry-run --no-syncthing --no-backup --profile minimal > /tmp/setup-dry-run.log 2>&1; then
    echo "❌ FAIL: Dry-run setup failed"
    cat /tmp/setup-dry-run.log
    exit 1
fi

if ! grep -q "DRY RUN MODE" /tmp/setup-dry-run.log; then
    echo "❌ FAIL: Dry-run mode not indicated"
    exit 1
fi

echo "✅ Dry-run setup completed successfully"

# Test git-crypt setup (without actually initializing)
if [[ -f "dotfiles/.gitattributes" ]]; then
    echo "✅ git-crypt gitattributes configured"
else
    echo "❌ FAIL: git-crypt gitattributes not found"
    exit 1
fi

# Test backup configuration
if [[ -f "backup/restic-config.conf" ]]; then
    echo "✅ Backup configuration exists"
else
    echo "❌ FAIL: Backup configuration not found"
    exit 1
fi

echo "✅ PASS: Ubuntu integration test completed successfully"

# Cleanup
rm -rf "$TEST_HOME"
