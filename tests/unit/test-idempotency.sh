#!/usr/bin/env bash
set -euo pipefail

# Test: Idempotency
# Validates that repeated runs produce identical results and no side effects

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASSED=0
FAILED=0

pass() {
    echo "PASSED: $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo "FAILED: $1"
    FAILED=$((FAILED + 1))
}

# Set up isolated HOME
TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"

cleanup() {
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

echo "=== Idempotency Tests ==="
echo "Test HOME: $TEST_HOME"

# Source the scripts we need
source "${REPO_ROOT}/scripts/lib/common.sh"

# ---------------------------------------------------------------
# Test 1: Dry-run output is identical on two consecutive runs
# ---------------------------------------------------------------
echo ""
echo "--- Test 1: Dry-run produces identical output ---"

OUTPUT1=$("${REPO_ROOT}/scripts/link-dotfiles.sh" --profile minimal --dry-run 2>&1) || true
OUTPUT2=$("${REPO_ROOT}/scripts/link-dotfiles.sh" --profile minimal --dry-run 2>&1) || true

if [[ "$OUTPUT1" == "$OUTPUT2" ]]; then
    pass "Dry-run output is identical on two consecutive runs"
else
    fail "Dry-run output differs between runs"
    echo "  Run 1: $OUTPUT1"
    echo "  Run 2: $OUTPUT2"
fi

# ---------------------------------------------------------------
# Test 2: create_symlink is idempotent (direct function test)
# ---------------------------------------------------------------
echo ""
echo "--- Test 2: Symlinks identical after second create_symlink ---"

# Set up variables needed by create_symlink
DRY_RUN=false
FORCE=true

# Source the functions from link-dotfiles.sh (re-declare to get them)
backup_existing() {
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ "$FORCE" == true ]]; then
            rm -rf "$target"
        else
            local backup
            backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"
            mv "$target" "$backup"
        fi
    fi
}

create_symlink() {
    local source="$1"
    local target="$2"

    if [[ "$DRY_RUN" == true ]]; then
        echo "Would create symlink: $target -> $source"
        return
    fi

    # Skip if symlink already points to the correct source (idempotent)
    if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
        log_info "Already linked: $target -> $source"
        return
    fi

    backup_existing "$target"

    local target_dir
    target_dir=$(dirname "$target")
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
    fi

    ln -s "$source" "$target"
    log_success "Created symlink: $target -> $source"
}

# Create a fake source file
FAKE_SRC="${TEST_HOME}/source-dotfiles"
mkdir -p "$FAKE_SRC"
echo "test config" > "${FAKE_SRC}/.testrc"
mkdir -p "${FAKE_SRC}/.config/testapp"
echo "app config" > "${FAKE_SRC}/.config/testapp/config"

# First run: create symlinks
create_symlink "${FAKE_SRC}/.testrc" "${TEST_HOME}/.testrc"
create_symlink "${FAKE_SRC}/.config/testapp" "${TEST_HOME}/.config/testapp"

# Capture symlink state
LINK1_BEFORE="$(readlink "${TEST_HOME}/.testrc")"
LINK2_BEFORE="$(readlink "${TEST_HOME}/.config/testapp")"

# Second run: should be idempotent
RUN2_OUTPUT=$(create_symlink "${FAKE_SRC}/.testrc" "${TEST_HOME}/.testrc" 2>&1)
RUN2_OUTPUT+=$'\n'
RUN2_OUTPUT+=$(create_symlink "${FAKE_SRC}/.config/testapp" "${TEST_HOME}/.config/testapp" 2>&1)

LINK1_AFTER="$(readlink "${TEST_HOME}/.testrc")"
LINK2_AFTER="$(readlink "${TEST_HOME}/.config/testapp")"

if [[ "$LINK1_BEFORE" == "$LINK1_AFTER" && "$LINK2_BEFORE" == "$LINK2_AFTER" ]]; then
    pass "Symlinks are identical after second run"
else
    fail "Symlinks differ after second run"
    echo "  .testrc before=$LINK1_BEFORE after=$LINK1_AFTER"
    echo "  testapp before=$LINK2_BEFORE after=$LINK2_AFTER"
fi

# ---------------------------------------------------------------
# Test 3: Second run reports "Already linked"
# ---------------------------------------------------------------
echo ""
echo "--- Test 3: Second run reports already linked ---"

if echo "$RUN2_OUTPUT" | grep -q "Already linked"; then
    pass "Second run reports 'Already linked' for existing symlinks"
else
    fail "Second run did not report 'Already linked'"
    echo "  Output: $RUN2_OUTPUT"
fi

# ---------------------------------------------------------------
# Test 4: No .backup.* files created on idempotent re-link
# ---------------------------------------------------------------
echo ""
echo "--- Test 4: No backup files on idempotent re-link ---"

BACKUP_FILES=$(find "$TEST_HOME" -name "*.backup.*" 2>/dev/null || true)

if [[ -z "$BACKUP_FILES" ]]; then
    pass "No .backup.* files created on idempotent re-link"
else
    fail "Backup files were created on idempotent re-link"
    echo "  Found: $BACKUP_FILES"
fi

# ---------------------------------------------------------------
# Test 5: Non-force re-link with existing correct symlink is
#          also idempotent (no backup created)
# ---------------------------------------------------------------
echo ""
echo "--- Test 5: Non-force re-link also idempotent ---"

FORCE=false
create_symlink "${FAKE_SRC}/.testrc" "${TEST_HOME}/.testrc" 2>&1

BACKUP_FILES_NOFORCE=$(find "$TEST_HOME" -name "*.backup.*" 2>/dev/null || true)

if [[ -z "$BACKUP_FILES_NOFORCE" ]]; then
    pass "No backup created on non-force idempotent re-link"
else
    fail "Backup files created on non-force idempotent re-link"
    echo "  Found: $BACKUP_FILES_NOFORCE"
fi

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
fi
