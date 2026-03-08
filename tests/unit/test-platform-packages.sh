#!/usr/bin/env bash
set -euo pipefail

# Test: Platform Package Definitions
# Validates that each platform has valid package definitions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/scripts/yaml-parser.sh"

PLATFORM="${1:-ubuntu}"

echo "Testing package definitions for platform: $PLATFORM"

PLATFORM_FILE="${REPO_ROOT}/packages/platforms/${PLATFORM}.yaml"

if [[ ! -f "$PLATFORM_FILE" ]]; then
    echo "❌ FAIL: Platform file not found: $PLATFORM_FILE"
    exit 1
fi

PLATFORM_CONTENT=$(cat "$PLATFORM_FILE")

# Check required fields
PLATFORM_NAME=$(yaml_get "$PLATFORM_CONTENT" "platform" "")
if [[ -z "$PLATFORM_NAME" || "$PLATFORM_NAME" == "null" ]]; then
    echo "❌ FAIL: Platform file missing 'platform' field"
    exit 1
fi

if [[ "$PLATFORM_NAME" != "$PLATFORM" ]]; then
    echo "❌ FAIL: Platform name mismatch. Expected: $PLATFORM, Got: $PLATFORM_NAME"
    exit 1
fi

PACKAGE_MANAGER=$(yaml_get "$PLATFORM_CONTENT" "package_manager" "")
if [[ -z "$PACKAGE_MANAGER" || "$PACKAGE_MANAGER" == "null" ]]; then
    echo "❌ FAIL: Platform file missing 'package_manager' field"
    exit 1
fi

echo "Platform: $PLATFORM_NAME"
echo "Package Manager: $PACKAGE_MANAGER"

# Check that base packages exist
BASE_PACKAGES=$(yaml_get_list "$PLATFORM_CONTENT" "packages.base")
if [[ -n "$BASE_PACKAGES" ]]; then
    echo "Base packages: $(echo "$BASE_PACKAGES" | head -3)"
    echo "✅ Platform has base packages"
else
    echo "⚠️  Warning: Platform has no base packages"
fi

# Platform-specific checks
case "$PLATFORM" in
    ubuntu|fedora|raspberrypios)
        # Check for apt/dnf repos if defined
        REPOS=$(yaml_get_list "$PLATFORM_CONTENT" "apt_repos")
        if [[ -n "$REPOS" ]]; then
            echo "✅ Platform has repository configurations"
        fi
        ;;
    gentoo)
        # Check for USE flags
        USE_FLAGS=$(yaml_get "$PLATFORM_CONTENT" "features.use_flags" "")
        if [[ -n "$USE_FLAGS" && "$USE_FLAGS" != "null" ]]; then
            echo "✅ Gentoo has USE flags configured"
        fi
        ;;
    windows)
        # Check for WSL instructions
        WSL=$(yaml_get "$PLATFORM_CONTENT" "wsl" "")
        if [[ -n "$WSL" ]]; then
            echo "✅ Windows has WSL configuration"
        fi
        ;;
esac

echo "✅ PASS: Platform package definitions are valid for $PLATFORM"
