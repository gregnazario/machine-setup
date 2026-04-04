#!/usr/bin/env bash
set -euo pipefail

# Test: NixOS Platform Support
# Verifies the script/config structure for NixOS support (grep-based, no nix needed)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASS=0
FAIL=0

check() {
    local description="$1"
    shift
    if "$@"; then
        echo "✅ PASS: $description"
        PASS=$((PASS + 1))
    else
        echo "❌ FAIL: $description"
        FAIL=$((FAIL + 1))
    fi
}

# 1. platform-detect.sh has nixos detection
check "platform-detect.sh contains nixos case" \
    grep -q 'nixos)' "${REPO_ROOT}/scripts/platform-detect.sh"

check "platform-detect.sh sets PLATFORM=nixos" \
    grep -q 'PLATFORM="nixos"' "${REPO_ROOT}/scripts/platform-detect.sh"

check "platform-detect.sh sets PACKAGE_MANAGER=nix" \
    grep -q 'PACKAGE_MANAGER="nix"' "${REPO_ROOT}/scripts/platform-detect.sh"

# 2. nixos.conf exists with correct fields
check "nixos.conf exists" \
    test -f "${REPO_ROOT}/packages/platforms/nixos.conf"

check "nixos.conf has platform name" \
    grep -q 'name = nixos' "${REPO_ROOT}/packages/platforms/nixos.conf"

check "nixos.conf has package_manager = nix" \
    grep -q 'package_manager = nix' "${REPO_ROOT}/packages/platforms/nixos.conf"

check "nixos.conf has base packages" \
    grep -q '\[packages.base\]' "${REPO_ROOT}/packages/platforms/nixos.conf"

# 3. install-packages.sh has install_packages_nix
check "install-packages.sh has install_packages_nix function" \
    grep -q 'install_packages_nix()' "${REPO_ROOT}/scripts/install-packages.sh"

check "install-packages.sh has nix case in dispatcher" \
    grep -q 'nix)' "${REPO_ROOT}/scripts/install-packages.sh"

# 4. common.conf has nixos mappings
check "common.conf has nixos fd mapping" \
    grep -q 'nixos = fd' "${REPO_ROOT}/packages/common.conf"

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi

echo "✅ All NixOS platform tests passed"
