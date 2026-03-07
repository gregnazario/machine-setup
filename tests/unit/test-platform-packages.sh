#!/usr/bin/env bash
set -euo pipefail

# Test: Platform Package Definitions
# Validates that each platform has valid package definitions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PLATFORM="${1:-ubuntu}"

echo "Testing package definitions for platform: $PLATFORM"

PLATFORM_FILE="${REPO_ROOT}/packages/platforms/${PLATFORM}.yaml"

if [[ ! -f "$PLATFORM_FILE" ]]; then
    echo "❌ FAIL: Platform file not found: $PLATFORM_FILE"
    exit 1
fi

# Validate YAML syntax
if ! yq eval '.' "$PLATFORM_FILE" > /dev/null 2>&1; then
    echo "❌ FAIL: $PLATFORM_FILE is not valid YAML"
    exit 1
fi

# Check required fields
PLATFORM_NAME=$(yq eval '.platform' "$PLATFORM_FILE")
if [[ -z "$PLATFORM_NAME" || "$PLATFORM_NAME" == "null" ]]; then
    echo "❌ FAIL: Platform file missing 'platform' field"
    exit 1
fi

if [[ "$PLATFORM_NAME" != "$PLATFORM" ]]; then
    echo "❌ FAIL: Platform name mismatch. Expected: $PLATFORM, Got: $PLATFORM_NAME"
    exit 1
fi

PACKAGE_MANAGER=$(yq eval '.package_manager' "$PLATFORM_FILE")
if [[ -z "$PACKAGE_MANAGER" || "$PACKAGE_MANAGER" == "null" ]]; then
    echo "❌ FAIL: Platform file missing 'package_manager' field"
    exit 1
fi

echo "Platform: $PLATFORM_NAME"
echo "Package Manager: $PACKAGE_MANAGER"

# Check that base packages exist
BASE_PACKAGES=$(yq eval '.packages.base[]?' "$PLATFORM_FILE")
if [[ -n "$BASE_PACKAGES" && "$BASE_PACKAGES" != "null" ]]; then
    echo "Base packages: $(echo "$BASE_PACKAGES" | head -3)"
    echo "✅ Platform has base packages"
else
    echo "⚠️  Warning: Platform has no base packages"
fi

# Platform-specific checks
case "$PLATFORM" in
    ubuntu|fedora|raspberrypios)
        # Check for apt/dnf repos if defined
        REPOS=$(yq eval '.apt_repos[]?' "$PLATFORM_FILE")
        if [[ -n "$REPOS" ]]; then
            echo "✅ Platform has repository configurations"
        fi
        ;;
    gentoo)
        # Check for USE flags
        USE_FLAGS=$(yq eval '.features.use_flags' "$PLATFORM_FILE")
        if [[ -n "$USE_FLAGS" && "$USE_FLAGS" != "null" ]]; then
            echo "✅ Gentoo has USE flags configured"
        fi
        ;;
    windows)
        # Check for WSL instructions
        WSL=$(yq eval '.wsl' "$PLATFORM_FILE")
        if [[ -n "$WSL" ]]; then
            echo "✅ Windows has WSL configuration"
        fi
        ;;
esac

echo "✅ PASS: Platform package definitions are valid for $PLATFORM"
