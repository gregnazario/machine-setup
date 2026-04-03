#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/../.."

passed=0
failed=0

check() {
    local description="$1"
    local result="$2"
    if [[ "$result" == "true" ]]; then
        echo "PASSED: $description"
        passed=$((passed + 1))
    else
        echo "FAILED: $description"
        failed=$((failed + 1))
    fi
}

# 1. platform-detect.sh contains PLATFORM="wsl"
if grep -q 'PLATFORM="wsl"' "${REPO_ROOT}/scripts/platform-detect.sh"; then
    check 'platform-detect.sh contains PLATFORM="wsl"' "true"
else
    check 'platform-detect.sh contains PLATFORM="wsl"' "false"
fi

# 2. platform-detect.sh assigns PACKAGE_MANAGER="apt" for WSL
wsl_block=$(grep -A1 'PLATFORM="wsl"' "${REPO_ROOT}/scripts/platform-detect.sh" || true)
if echo "$wsl_block" | grep -q 'PACKAGE_MANAGER="apt"'; then
    check 'platform-detect.sh assigns PACKAGE_MANAGER="apt" for WSL' "true"
else
    check 'platform-detect.sh assigns PACKAGE_MANAGER="apt" for WSL' "false"
fi

# 3. packages/platforms/wsl.conf exists
if [[ -f "${REPO_ROOT}/packages/platforms/wsl.conf" ]]; then
    check 'packages/platforms/wsl.conf exists' "true"
else
    check 'packages/platforms/wsl.conf exists' "false"
fi

# 4. install-packages.sh has apt support
if grep -q 'apt' "${REPO_ROOT}/scripts/install-packages.sh"; then
    check 'install-packages.sh has apt support' "true"
else
    check 'install-packages.sh has apt support' "false"
fi

# 5. platform-detect.sh checks for microsoft in uname
if grep -q 'microsoft' "${REPO_ROOT}/scripts/platform-detect.sh"; then
    check 'platform-detect.sh checks for microsoft in uname' "true"
else
    check 'platform-detect.sh checks for microsoft in uname' "false"
fi

echo ""
echo "Results: ${passed} passed, ${failed} failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
