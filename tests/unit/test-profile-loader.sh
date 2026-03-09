#!/usr/bin/env bash
set -euo pipefail

# Test: Profile Loader
# Validates that profiles load correctly and contain expected data

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PROFILE="${1:-minimal}"

echo "Testing profile loader for profile: $PROFILE"

# Source the profile loader
source "${REPO_ROOT}/scripts/platform-detect.sh"
source "${REPO_ROOT}/scripts/ini-parser.sh"
source "${REPO_ROOT}/scripts/profile-loader.sh"

# Test profile loading
load_profile "$PROFILE"

# Validate profile data
if [[ -z "$PROFILE_NAME" ]]; then
    echo "❌ FAIL: Profile name not set"
    exit 1
fi

if [[ "$PROFILE_NAME" != "$PROFILE" ]]; then
    echo "❌ FAIL: Profile name mismatch. Expected: $PROFILE, Got: $PROFILE_NAME"
    exit 1
fi

# Check that profile has packages
PACKAGES=$(get_profile_packages)
if [[ -z "$PACKAGES" || "$PACKAGES" == "null" ]]; then
    echo "❌ FAIL: No packages found in profile"
    exit 1
fi

# Check that profile has dotfiles
DOTFILES=$(get_profile_dotfiles)
if [[ -z "$DOTFILES" || "$DOTFILES" == "null" ]]; then
    echo "❌ FAIL: No dotfiles found in profile"
    exit 1
fi

# Check for required fields
NAME=$(ini_get "$PROFILE_FILE" "profile" "name" "")
if [[ -z "$NAME" ]]; then
    echo "❌ FAIL: Profile missing 'name' field"
    exit 1
fi

DESCRIPTION=$(ini_get "$PROFILE_FILE" "profile" "description" "")
if [[ -z "$DESCRIPTION" ]]; then
    echo "❌ FAIL: Profile missing 'description' field"
    exit 1
fi

# Validate minimal profile has essential packages
if [[ "$PROFILE" == "minimal" ]]; then
    if ! echo "$PACKAGES" | grep -q "nushell"; then
        echo "❌ FAIL: Minimal profile missing 'nushell'"
        exit 1
    fi
    if ! echo "$PACKAGES" | grep -q "neovim"; then
        echo "❌ FAIL: Minimal profile missing 'neovim'"
        exit 1
    fi
    echo "✅ Minimal profile contains essential packages"
fi

# Validate full profile has extended packages
if [[ "$PROFILE" == "full" ]]; then
    if ! echo "$PACKAGES" | grep -q "zellij"; then
        echo "❌ FAIL: Full profile missing 'zellij'"
        exit 1
    fi
    if ! echo "$PACKAGES" | grep -q "bat"; then
        echo "❌ FAIL: Full profile missing 'bat'"
        exit 1
    fi
    echo "✅ Full profile contains extended packages"
fi

echo "✅ PASS: Profile loader test completed successfully for $PROFILE"
