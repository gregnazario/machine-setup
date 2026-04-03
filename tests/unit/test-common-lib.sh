#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/../.."

source "${REPO_ROOT}/scripts/lib/common.sh"

status=0

# Verify each function exists
for fn in log_info log_warn log_error log_success; do
    if ! declare -f "$fn" > /dev/null 2>&1; then
        echo "FAIL: $fn is not defined"
        status=1
    fi
done

# Verify output contains correct tag and message
check_output() {
    local fn="$1"
    local tag="$2"
    local msg="test message from $fn"
    local output
    output=$("$fn" "$msg")
    if [[ "$output" != *"[$tag]"* ]]; then
        echo "FAIL: $fn output missing [$tag] tag"
        echo "  got: $output"
        status=1
        return
    fi
    if [[ "$output" != *"$msg"* ]]; then
        echo "FAIL: $fn output missing message text"
        echo "  got: $output"
        status=1
        return
    fi
    echo "PASS: $fn"
}

check_output log_info "INFO"
check_output log_warn "WARN"
check_output log_error "ERROR"
check_output log_success "SUCCESS"

# Verify double-source guard works
source "${REPO_ROOT}/scripts/lib/common.sh"
echo "PASS: double-source guard"

if [[ $status -eq 0 ]]; then
    echo "All common library tests passed"
else
    echo "Some tests failed"
fi
exit $status
