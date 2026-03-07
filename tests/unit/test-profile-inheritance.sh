#!/usr/bin/env bash
set -euo pipefail

# Test: Profile Inheritance
# Validates that profile inheritance works correctly

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Testing profile inheritance"

source "${REPO_ROOT}/scripts/platform-detect.sh"
source "${REPO_ROOT}/scripts/profile-loader.sh"

# Test that full profile extends minimal
load_profile "full"

# Full profile should have all minimal packages plus extra
if ! echo "$PROFILE_DATA" | grep -q "nushell"; then
    echo "❌ FAIL: Full profile doesn't include minimal packages (nushell)"
    exit 1
fi

if ! echo "$PROFILE_DATA" | grep -q "neovim"; then
    echo "❌ FAIL: Full profile doesn't include minimal packages (neovim)"
    exit 1
fi

# Full profile should have additional packages
if ! echo "$PROFILE_DATA" | grep -q "zellij"; then
    echo "❌ FAIL: Full profile missing extended packages (zellij)"
    exit 1
fi

# Check services are inherited and extended
SERVICES=$(get_profile_services)
if [[ -z "$SERVICES" ]]; then
    echo "❌ FAIL: No services found in full profile"
    exit 1
fi

echo "✅ PASS: Profile inheritance works correctly"
