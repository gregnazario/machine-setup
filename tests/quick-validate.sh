#!/usr/bin/env bash
set -euo pipefail

# Quick validation script to test basic functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Quick Validation"
echo "================"

cd "$REPO_ROOT"

# 1. Check all required files exist
echo "1. Checking required files..."
REQUIRED_FILES=(
    "setup.sh"
    "README.md"
    "PLAN.md"
    "AGENTS.md"
    "packages/common.conf"
    "profiles/minimal.conf"
    "profiles/full.conf"
    "scripts/platform-detect.sh"
    "scripts/profile-loader.sh"
    "scripts/install-packages.sh"
    "scripts/link-dotfiles.sh"
    "backup/restic-config.conf"
    "dotfiles/.gitattributes"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "❌ Missing: $file"
        exit 1
    fi
done
echo "✅ All required files present"

# 2. Check scripts are executable
echo "2. Checking script permissions..."
for script in setup.sh scripts/*.sh; do
    if [[ -f "$script" && ! -x "$script" ]]; then
        echo "❌ Not executable: $script"
        exit 1
    fi
done
echo "✅ All scripts are executable"

# 3. Validate INI config files
echo "3. Validating INI config files..."
for ini_file in packages/*.conf packages/platforms/*.conf profiles/*.conf backup/*.conf; do
    if [[ -f "$ini_file" ]]; then
        if ! grep -q "^\[" "$ini_file" 2>/dev/null; then
            echo "❌ Invalid INI: $ini_file (no sections found)"
            exit 1
        fi
    fi
done
echo "✅ All INI config files are valid"

# 4. Test platform detection
echo "4. Testing platform detection..."
source scripts/platform-detect.sh
detect_platform
if [[ -z "$PLATFORM" || -z "$PACKAGE_MANAGER" ]]; then
    echo "❌ Platform detection failed"
    exit 1
fi
echo "✅ Detected: $PLATFORM with $PACKAGE_MANAGER"

# 5. Test profile loading
echo "5. Testing profile loading..."
source scripts/ini-parser.sh
source scripts/profile-loader.sh
load_profile "minimal"
if [[ "$PROFILE_NAME" != "minimal" ]]; then
    echo "❌ Profile loading failed"
    exit 1
fi
echo "✅ Profile loaded: $PROFILE_NAME"

# 6. Test dry-run
echo "6. Testing dry-run mode..."
if ./setup.sh --dry-run --no-syncthing --no-backup > /tmp/quick-validation.log 2>&1; then
    echo "✅ Dry-run completed successfully"
else
    echo "❌ Dry-run failed"
    cat /tmp/quick-validation.log
    exit 1
fi

echo ""
echo "================"
echo "✅ All validation checks passed!"
echo ""
