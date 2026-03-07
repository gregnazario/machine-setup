#!/usr/bin/env bash
set -euo pipefail

# Test: Package Collection
# Validates that packages are collected correctly for installation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Testing package collection"

source "${REPO_ROOT}/scripts/platform-detect.sh"
source "${REPO_ROOT}/scripts/profile-loader.sh"

detect_platform
load_profile "minimal"

# Test package mapping function
source "${REPO_ROOT}/scripts/install-packages.sh"

# Test that fd-find gets mapped correctly
MAPPED_FD=$(get_mapped_package_name "fd-find")

echo "Package 'fd-find' mapped to: $MAPPED_FD"

if [[ -z "$MAPPED_FD" ]]; then
    echo "❌ FAIL: Package mapping returned empty"
    exit 1
fi

# Test collecting packages
PACKAGES=$(collect_packages)

if [[ -z "$PACKAGES" ]]; then
    echo "❌ FAIL: No packages collected"
    exit 1
fi

# Check for essential packages
if ! echo "$PACKAGES" | grep -q "git"; then
    echo "❌ FAIL: Essential package 'git' not in collection"
    exit 1
fi

if ! echo "$PACKAGES" | grep -q "nushell"; then
    echo "❌ FAIL: Essential package 'nushell' not in collection"
    exit 1
fi

echo "Collected packages: ${PACKAGES:0:100}..."

echo "✅ PASS: Package collection works correctly"
