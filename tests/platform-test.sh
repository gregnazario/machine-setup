#!/usr/bin/env bash
set -euo pipefail

# Platform Test Script
# Runs inside each platform (native or container) to validate:
# 1. Platform detection works
# 2. Profile loading works
# 3. Package collection and mapping works
# 4. Dotfiles structure is valid
# 5. Dry-run setup completes
# 6. (Optional) Actual package installation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

EXPECTED_PLATFORM="${1:-}"
EXPECTED_PKG_MGR="${2:-}"
INSTALL_PACKAGES="${3:-false}"

PASSED=0
FAILED=0

pass() {
    echo "  ✅ $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo "  ❌ $1"
    FAILED=$((FAILED + 1))
}

echo "========================================="
echo "Platform Test"
echo "========================================="
echo ""

# --------------------------------------------------
# 1. Platform detection
# --------------------------------------------------
echo "1. Platform detection"

source "${REPO_ROOT}/scripts/platform-detect.sh"
detect_platform

DETECTED_PLATFORM="$PLATFORM"
DETECTED_PKG_MGR="$PACKAGE_MANAGER"

if [[ -z "$DETECTED_PLATFORM" ]]; then
    fail "PLATFORM is empty"
else
    pass "Detected platform: $DETECTED_PLATFORM"
fi

if [[ -z "$DETECTED_PKG_MGR" ]]; then
    fail "PACKAGE_MANAGER is empty"
else
    pass "Detected package manager: $DETECTED_PKG_MGR"
fi

if [[ -n "$EXPECTED_PLATFORM" && "$DETECTED_PLATFORM" != "$EXPECTED_PLATFORM" ]]; then
    fail "Expected platform '$EXPECTED_PLATFORM', got '$DETECTED_PLATFORM'"
fi

if [[ -n "$EXPECTED_PKG_MGR" && "$DETECTED_PKG_MGR" != "$EXPECTED_PKG_MGR" ]]; then
    fail "Expected package manager '$EXPECTED_PKG_MGR', got '$DETECTED_PKG_MGR'"
fi

echo ""

# --------------------------------------------------
# 2. Platform package definitions
# --------------------------------------------------
echo "2. Platform package definitions"

source "${REPO_ROOT}/scripts/ini-parser.sh"

PLATFORM_FILE="${REPO_ROOT}/packages/platforms/${PLATFORM}.conf"
if [[ -f "$PLATFORM_FILE" ]]; then
    PLAT_NAME=$(ini_get "$PLATFORM_FILE" "platform" "name" "")
    if [[ -n "$PLAT_NAME" ]]; then
        pass "Platform conf has name: $PLAT_NAME"
    else
        fail "Platform conf missing 'name' field"
    fi

    PLAT_PKG_MGR=$(ini_get "$PLATFORM_FILE" "platform" "package_manager" "")
    if [[ -n "$PLAT_PKG_MGR" ]]; then
        pass "Platform conf has package_manager: $PLAT_PKG_MGR"
    else
        fail "Platform conf missing 'package_manager' field"
    fi
else
    fail "Platform file not found: $PLATFORM_FILE"
fi

echo ""

# --------------------------------------------------
# 3. Profile loading
# --------------------------------------------------
echo "3. Profile loading"

source "${REPO_ROOT}/scripts/profile-loader.sh"

# Test minimal
load_profile "minimal"
if [[ "$PROFILE_NAME" == "minimal" ]]; then
    pass "Loaded minimal profile"
else
    fail "Failed to load minimal profile (got: $PROFILE_NAME)"
fi

PACKAGES=$(get_profile_packages)
if echo "$PACKAGES" | grep -q "nushell"; then
    pass "Minimal profile contains nushell"
else
    fail "Minimal profile missing nushell"
fi

if echo "$PACKAGES" | grep -q "neovim"; then
    pass "Minimal profile contains neovim"
else
    fail "Minimal profile missing neovim"
fi

# Test full (with inheritance)
load_profile "full"
if [[ "$PROFILE_NAME" == "full" ]]; then
    pass "Loaded full profile"
else
    fail "Failed to load full profile (got: $PROFILE_NAME)"
fi

FULL_PACKAGES=$(get_profile_packages)
if echo "$FULL_PACKAGES" | grep -q "zellij"; then
    pass "Full profile contains zellij"
else
    fail "Full profile missing zellij"
fi

# Inherited from minimal
if echo "$FULL_PACKAGES" | grep -q "nushell"; then
    pass "Full profile inherits nushell from minimal"
else
    fail "Full profile missing inherited nushell"
fi

echo ""

# --------------------------------------------------
# 4. Package collection and mapping
# --------------------------------------------------
echo "4. Package collection and mapping"

source "${REPO_ROOT}/scripts/install-packages.sh"

load_profile "minimal"
COLLECTED=$(collect_packages)
if [[ -n "$COLLECTED" ]]; then
    PKG_COUNT=$(echo "$COLLECTED" | wc -w | tr -d ' ')
    pass "Collected $PKG_COUNT packages for minimal profile"
else
    fail "No packages collected for minimal"
fi

# Test that fd-find gets mapped on this platform
MAPPED_FD=$(get_mapped_package_name "fd-find")
if [[ -n "$MAPPED_FD" ]]; then
    pass "fd-find mapped to: $MAPPED_FD"
else
    fail "fd-find mapping returned empty"
fi

echo ""

# --------------------------------------------------
# 5. Dotfiles structure
# --------------------------------------------------
echo "5. Dotfiles structure"

load_profile "minimal"
DOTFILES_SOURCE=$(ini_get "$PROFILE_FILE" "dotfiles" "source" "")
DOTFILES_DIR="${REPO_ROOT}/dotfiles/${DOTFILES_SOURCE}"

if [[ -d "$DOTFILES_DIR" ]]; then
    pass "Minimal dotfiles directory exists: $DOTFILES_SOURCE"
else
    fail "Minimal dotfiles directory not found: $DOTFILES_DIR"
fi

load_profile "full"
DOTFILES_SOURCE=$(ini_get "$PROFILE_FILE" "dotfiles" "source" "")
DOTFILES_DIR="${REPO_ROOT}/dotfiles/${DOTFILES_SOURCE}"

if [[ -d "$DOTFILES_DIR" ]]; then
    pass "Full dotfiles directory exists: $DOTFILES_SOURCE"
else
    fail "Full dotfiles directory not found: $DOTFILES_DIR"
fi

echo ""

# --------------------------------------------------
# 6. Dry-run setup
# --------------------------------------------------
echo "6. Dry-run setup"

export HOME="${HOME:-/tmp/test-home}"
mkdir -p "$HOME"

if ! command -v git &> /dev/null; then
    echo "  (skipped — git not available in this environment)"
else
    if bash "${REPO_ROOT}/setup.sh" --dry-run --no-syncthing --no-backup --profile minimal > /tmp/platform-test-dry-run.log 2>&1; then
        pass "Dry-run (minimal) completed"
    else
        fail "Dry-run (minimal) failed"
        cat /tmp/platform-test-dry-run.log
    fi

    if bash "${REPO_ROOT}/setup.sh" --dry-run --no-syncthing --no-backup --profile full > /tmp/platform-test-dry-run.log 2>&1; then
        pass "Dry-run (full) completed"
    else
        fail "Dry-run (full) failed"
        cat /tmp/platform-test-dry-run.log
    fi
fi

echo ""

# --------------------------------------------------
# 7. (Optional) Package installation
# --------------------------------------------------
if [[ "$INSTALL_PACKAGES" == "true" ]]; then
    echo "7. Package installation (LIVE)"

    load_profile "minimal"
    COLLECTED=$(collect_packages)

    if bash "${REPO_ROOT}/scripts/install-packages.sh" --profile minimal 2>&1; then
        pass "Package installation succeeded"
    else
        fail "Package installation failed (non-fatal in CI)"
    fi

    echo ""
fi

# --------------------------------------------------
# Summary
# --------------------------------------------------
echo "========================================="
echo "Platform: $DETECTED_PLATFORM ($DETECTED_PKG_MGR)"
echo "Passed:   $PASSED"
echo "Failed:   $FAILED"
echo "========================================="

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
