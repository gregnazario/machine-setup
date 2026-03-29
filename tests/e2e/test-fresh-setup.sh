#!/usr/bin/env bash
set -euo pipefail

# E2E Test: Fresh Machine Setup Simulation
# Simulates setting up a fresh machine from scratch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/scripts/ini-parser.sh"

echo "========================================="
echo "E2E Test: Fresh Machine Setup Simulation"
echo "========================================="

# Create isolated test environment
TEST_HOME="/tmp/test-fresh-machine-$(date +%s)"
export TEST_HOME
mkdir -p "$TEST_HOME"

echo "Test environment: $TEST_HOME"
export HOME="$TEST_HOME"

cd "$REPO_ROOT"

# Step 1: Simulate fresh clone
echo ""
echo "Step 1: Simulating fresh repository clone..."
if [[ ! -f "setup.sh" ]]; then
    echo "❌ FAIL: setup.sh not found"
    exit 1
fi

if [[ ! -x "setup.sh" ]]; then
    echo "❌ FAIL: setup.sh is not executable"
    exit 1
fi

echo "✅ Repository structure valid"

# Step 2: Platform detection
echo ""
echo "Step 2: Detecting platform..."
source scripts/platform-detect.sh
detect_platform

echo "Detected: $PLATFORM with $PACKAGE_MANAGER"

# Step 3: Profile selection
echo ""
echo "Step 3: Selecting profile..."
source scripts/profile-loader.sh
DEFAULT_PROFILE=$(get_default_profile_for_platform)
echo "Default profile: $DEFAULT_PROFILE"

# Step 4: Load profile
echo ""
echo "Step 4: Loading profile..."
load_profile "$DEFAULT_PROFILE"

PACKAGES=$(get_profile_packages | grep -c "  - " || true)
DOTFILES_CONFIG=$(get_profile_dotfiles)
DOTFILES=$(echo "$DOTFILES_CONFIG" | grep -c "  - src:" || true)
SERVICES=$(get_profile_services | wc -l)

echo "Profile: $PROFILE_NAME"
echo "  - Packages: $PACKAGES"
echo "  - Dotfile links: $DOTFILES"
echo "  - Services: $SERVICES"

# Step 5: Validate package definitions
echo ""
echo "Step 5: Validating package definitions..."
source scripts/install-packages.sh

ALL_PACKAGES=$(collect_packages)
PACKAGE_COUNT=$(echo "$ALL_PACKAGES" | wc -w)

echo "Total packages to install: $PACKAGE_COUNT"

# Step 6: Validate dotfiles
echo ""
echo "Step 6: Validating dotfiles..."
DOTFILES_SOURCE=$(ini_get "$PROFILE_FILE" "dotfiles" "source" "")
DOTFILES_DIR="${REPO_ROOT}/dotfiles/${DOTFILES_SOURCE}"

if [[ ! -d "$DOTFILES_DIR" ]]; then
    echo "❌ FAIL: Dotfiles directory not found: $DOTFILES_DIR"
    exit 1
fi

DOTFILE_COUNT=$(find "$DOTFILES_DIR" -type f | wc -l)
echo "Dotfiles found: $DOTFILE_COUNT"

# Step 7: Validate secrets configuration
echo ""
echo "Step 7: Validating secrets configuration..."
if [[ -f "dotfiles/.gitattributes" ]]; then
    ENCRYPTION_RULES=$(grep -c "filter=git-crypt" dotfiles/.gitattributes)
    echo "Encryption rules: $ENCRYPTION_RULES"
else
    echo "❌ FAIL: git-crypt gitattributes not found"
    exit 1
fi

# Step 8: Validate backup configuration
echo ""
echo "Step 8: Validating backup configuration..."
if [[ -f "backup/restic-config.conf" ]]; then
    BACKUP_PATHS=$(grep -c "^\[paths\]" backup/restic-config.conf || echo "0")
    echo "Backup paths section found"
else
    echo "❌ FAIL: Backup config not found"
    exit 1
fi

if [[ -f "backup/backup.sh" ]]; then
    if [[ ! -x "backup/backup.sh" ]]; then
        echo "❌ FAIL: backup.sh is not executable"
        exit 1
    fi
    echo "✅ Backup script is executable"
else
    echo "❌ FAIL: Backup script not found"
    exit 1
fi

# Step 9: Dry-run full setup
echo ""
echo "Step 9: Running dry-run setup..."
if ! ./setup.sh --dry-run --no-syncthing --no-backup > /tmp/e2e-dry-run.log 2>&1; then
    echo "❌ FAIL: Dry-run setup failed"
    cat /tmp/e2e-dry-run.log
    exit 1
fi

echo "✅ Dry-run setup completed"

# Step 10: Verify documentation
echo ""
echo "Step 10: Verifying documentation..."
DOCS="README.md PLAN.md AGENTS.md"
for doc in $DOCS; do
    if [[ ! -f "$doc" ]]; then
        echo "❌ FAIL: $doc not found"
        exit 1
    fi
    LINES=$(wc -l < "$doc")
    echo "  - $doc: $LINES lines"
done

# Step 11: Final validation
echo ""
echo "Step 11: Final validation..."
VALIDATION_PASSED=true

# Check all scripts are executable
for script in setup.sh scripts/*.sh; do
    if [[ ! -x "$script" ]]; then
        echo "❌ FAIL: $script is not executable"
        VALIDATION_PASSED=false
    fi
done

# Check all INI config files are valid
for ini_file in packages/*.conf packages/platforms/*.conf profiles/*.conf backup/*.conf; do
    if [[ -f "$ini_file" ]]; then
        if ! grep -q "^\[" "$ini_file" 2>/dev/null; then
            echo "❌ FAIL: $ini_file is not a valid INI file"
            VALIDATION_PASSED=false
        fi
    fi
done

if [[ "$VALIDATION_PASSED" == true ]]; then
    echo "✅ All validation checks passed"
else
    echo "❌ FAIL: Some validation checks failed"
    exit 1
fi

# Summary
echo ""
echo "========================================="
echo "E2E Test Summary:"
echo "========================================="
echo "Platform: $PLATFORM"
echo "Package Manager: $PACKAGE_MANAGER"
echo "Profile: $PROFILE_NAME"
echo "Packages: $PACKAGE_COUNT"
echo "Dotfiles: $DOTFILE_COUNT"
echo "Services: $SERVICES"
echo "Encryption Rules: $ENCRYPTION_RULES"
echo "Backup Paths: $BACKUP_PATHS"
echo ""
echo "✅ PASS: E2E test completed successfully!"
echo "========================================="

# Cleanup
rm -rf "$TEST_HOME"
