#!/usr/bin/env bash
set -euo pipefail

# Test: Platform Package Definitions
# Validates that each platform has valid package definitions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/scripts/ini-parser.sh"

PLATFORM="${1:-ubuntu}"

echo "Testing package definitions for platform: $PLATFORM"

PLATFORM_FILE="${REPO_ROOT}/packages/platforms/${PLATFORM}.conf"

if [[ ! -f "$PLATFORM_FILE" ]]; then
    echo "❌ FAIL: Platform file not found: $PLATFORM_FILE"
    exit 1
fi

# Check required fields
PLATFORM_NAME=$(ini_get "$PLATFORM_FILE" "platform" "name" "")
if [[ -z "$PLATFORM_NAME" ]]; then
    echo "❌ FAIL: Platform file missing 'name' field"
    exit 1
fi

if [[ "$PLATFORM_NAME" != "$PLATFORM" ]]; then
    echo "❌ FAIL: Platform name mismatch. Expected: $PLATFORM, Got: $PLATFORM_NAME"
    exit 1
fi

PACKAGE_MANAGER=$(ini_get "$PLATFORM_FILE" "platform" "package_manager" "")
if [[ -z "$PACKAGE_MANAGER" ]]; then
    echo "❌ FAIL: Platform file missing 'package_manager' field"
    exit 1
fi

echo "Platform: $PLATFORM_NAME"
echo "Package Manager: $PACKAGE_MANAGER"

# Check that base packages exist
BASE_PACKAGES=$(ini_get "$PLATFORM_FILE" "packages.base" "packages" "")
if [[ -n "$BASE_PACKAGES" ]]; then
    echo "Base packages: $(echo "$BASE_PACKAGES" | head -3)"
    echo "✅ Platform has base packages"
else
    echo "⚠️  Warning: Platform has no base packages"
fi

# Platform-specific checks (simplified for INI format)
case "$PLATFORM" in
    ubuntu|fedora|raspberrypios)
        # Check for repository sections
        if grep -q "\[repositories\." "$PLATFORM_FILE"; then
            echo "✅ Platform has repository configurations"
        fi
        ;;
    gentoo)
        # Check for USE flags
        USE_FLAGS=$(ini_get "$PLATFORM_FILE" "features" "use_flags" "")
        if [[ -n "$USE_FLAGS" ]]; then
            echo "✅ Gentoo has USE flags configured"
        fi
        ;;
    windows)
        # Check for WSL instructions
        WSL=$(ini_get "$PLATFORM_FILE" "platform" "wsl" "")
        if [[ -n "$WSL" ]]; then
            echo "✅ Windows has WSL configuration"
        fi
        ;;
esac

echo "✅ PASS: Platform package definitions are valid for $PLATFORM"
