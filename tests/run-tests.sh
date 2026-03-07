#!/usr/bin/env bash
set -euo pipefail

# Test Runner
# Runs all tests locally

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASSED=0
FAILED=0
TOTAL=0

run_test() {
    local test_name="$1"
    local test_path="$2"
    
    TOTAL=$((TOTAL + 1))
    echo ""
    echo "Running: $test_name"
    echo "----------------------------------------"
    
    if bash "$test_path" > /tmp/test-output.log 2>&1; then
        echo "✅ PASS: $test_name"
        PASSED=$((PASSED + 1))
    else
        echo "❌ FAIL: $test_name"
        cat /tmp/test-output.log
        FAILED=$((FAILED + 1))
    fi
}

echo "========================================="
echo "Running Local Test Suite"
echo "========================================="

cd "$REPO_ROOT"

# Check dependencies
echo "Checking dependencies..."
command -v yq >/dev/null 2>&1 || { echo "❌ yq is required but not installed."; exit 1; }
command -v bash >/dev/null 2>&1 || { echo "❌ bash is required but not installed."; exit 1; }
echo "✅ Dependencies satisfied"

# Run unit tests
echo ""
echo "========================================="
echo "Unit Tests"
echo "========================================="

for test_file in "${SCRIPT_DIR}"/unit/*.sh; do
    if [[ -f "$test_file" ]]; then
        test_name=$(basename "$test_file" .sh)
        run_test "$test_name" "$test_file"
    fi
done

# Run integration tests
echo ""
echo "========================================="
echo "Integration Tests"
echo "========================================="

for test_file in "${SCRIPT_DIR}"/integration/*.sh; do
    if [[ -f "$test_file" ]]; then
        test_name=$(basename "$test_file" .sh)
        run_test "$test_name" "$test_file"
    fi
done

# Run e2e tests
echo ""
echo "========================================="
echo "E2E Tests"
echo "========================================="

for test_file in "${SCRIPT_DIR}"/e2e/*.sh; do
    if [[ -f "$test_file" ]]; then
        test_name=$(basename "$test_file" .sh)
        run_test "$test_name" "$test_file"
    fi
done

# Summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Total:  $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed"
    exit 1
fi
