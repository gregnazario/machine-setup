#!/usr/bin/env bash
set -euo pipefail

# Integration Test: macOS Setup
# Tests the complete setup process on macOS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Running macOS integration test"

# Create isolated test environment
TEST_HOME="/tmp/test-macos-setup"
rm -rf "$TEST_HOME"
mkdir -p "$TEST_HOME"

# Mock home directory
export HOME="$TEST_HOME"

cd "$REPO_ROOT"

# Test platform detection
echo "Testing platform detection..."
source scripts/platform-detect.sh
detect_platform

if [[ "$PLATFORM" != "macos" ]]; then
    echo "❌ FAIL: Platform should be 'macos', got '$PLATFORM'"
    exit 1
fi

if [[ "$PACKAGE_MANAGER" != "homebrew" ]]; then
    echo "❌ FAIL: Package manager should be 'homebrew', got '$PACKAGE_MANAGER'"
    exit 1
fi

echo "✅ Platform detection: macOS with homebrew"

# Test profile loading
echo "Testing profile loading..."
source scripts/profile-loader.sh
load_profile "full"  # macOS defaults to full profile

if [[ "$PROFILE_NAME" != "full" ]]; then
    echo "❌ FAIL: Profile should be 'full', got '$PROFILE_NAME'"
    exit 1
fi

echo "✅ Profile loading: full"

# Test default profile detection
DEFAULT_PROFILE=$(get_default_profile_for_platform)

if [[ "$DEFAULT_PROFILE" != "full" ]]; then
    echo "❌ FAIL: Default profile should be 'full', got '$DEFAULT_PROFILE'"
    exit 1
fi

echo "✅ Default profile detection: full"

# Test package collection
echo "Testing package collection..."
source scripts/install-packages.sh
PACKAGES=$(collect_packages)

if [[ -z "$PACKAGES" ]]; then
    echo "❌ FAIL: No packages collected"
    exit 1
fi

echo "✅ Package collection: $(echo "$PACKAGES" | wc -w) packages"

# Test platform-specific packages
MACOS_PACKAGES="${REPO_ROOT}/packages/platforms/macos.yaml"
if [[ ! -f "$MACOS_PACKAGES" ]]; then
    echo "❌ FAIL: macOS platform packages file not found"
    exit 1
fi

# Check for macOS-specific configurations
HOMEBREW_TAPS=$(yq eval '.homebrew_taps[]?' "$MACOS_PACKAGES")
if [[ -n "$HOMEBREW_TAPS" ]]; then
    echo "✅ Homebrew taps configured: $(echo "$HOMEBREW_TAPS" | head -1)"
fi

# Check for OrbStack (Docker alternative for macOS)
PLATFORM_SPECIFIC=$(yq eval '.platform_specific[]?' "$MACOS_PACKAGES")
if echo "$PLATFORM_SPECIFIC" | grep -q "orbstack"; then
    echo "✅ OrbStack configured for macOS"
fi

# Test dry-run setup
echo "Testing dry-run setup..."
./setup.sh --dry-run --no-syncthing --no-backup --profile full > /tmp/setup-dry-run.log 2>&1

if [[ $? -ne 0 ]]; then
    echo "❌ FAIL: Dry-run setup failed"
    cat /tmp/setup-dry-run.log
    exit 1
fi

echo "✅ Dry-run setup completed successfully"

echo "✅ PASS: macOS integration test completed successfully"

# Cleanup
rm -rf "$TEST_HOME"
