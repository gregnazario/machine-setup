#!/usr/bin/env bash
# Unit tests for scripts/ini-parser.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../../scripts/ini-parser.sh
source "$REPO_ROOT/scripts/ini-parser.sh"

PASSED=0
FAILED=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASSED: $desc"
        PASSED=$((PASSED + 1))
    else
        echo "  FAILED: $desc"
        echo "    expected: '$expected'"
        echo "    actual:   '$actual'"
        FAILED=$((FAILED + 1))
    fi
}

# Create a temporary INI file for testing
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

cat > "$TMPFILE" << 'EOF'
[general]
key1 = value1
key2 = value2 # this is a comment
key3 = value with spaces
key4 = value4 ; semicolon comment
site = https://example.com#anchor
commented = https://example.com # a comment

[other]
key1 = other_value1
EOF

echo "=== INI Parser Unit Tests ==="

echo ""
echo "--- ini_get basic retrieval ---"
result=$(ini_get "$TMPFILE" general key1)
assert_eq "basic key retrieval" "value1" "$result"

echo ""
echo "--- ini_get inline hash comment ---"
result=$(ini_get "$TMPFILE" general key2)
assert_eq "inline hash comment stripped" "value2" "$result"

echo ""
echo "--- ini_get inline semicolon comment ---"
result=$(ini_get "$TMPFILE" general key4)
assert_eq "inline semicolon comment stripped" "value4" "$result"

echo ""
echo "--- ini_get value with spaces (no comment) ---"
result=$(ini_get "$TMPFILE" general key3)
assert_eq "value with spaces preserved" "value with spaces" "$result"

echo ""
echo "--- ini_get default value for missing key ---"
result=$(ini_get "$TMPFILE" general missing_key "default_val")
assert_eq "default value for missing key" "default_val" "$result"

echo ""
echo "--- cross-section isolation ---"
result=$(ini_get "$TMPFILE" other key1)
assert_eq "cross-section isolation" "other_value1" "$result"

echo ""
echo "--- ini_get_sections ---"
result=$(ini_get_sections "$TMPFILE")
expected=$(printf "general\nother")
assert_eq "ini_get_sections lists all sections" "$expected" "$result"

echo ""
echo "--- ini_get_all_keys ---"
result=$(ini_get_all_keys "$TMPFILE" general)
expected=$(printf "key1\nkey2\nkey3\nkey4\nsite\ncommented")
assert_eq "ini_get_all_keys lists all keys in section" "$expected" "$result"

echo ""
echo "--- hash without leading space preserved (URLs) ---"
result=$(ini_get "$TMPFILE" general site)
assert_eq "URL with hash anchor preserved" "https://example.com#anchor" "$result"

echo ""
echo "--- hash with leading space stripped ---"
result=$(ini_get "$TMPFILE" general commented)
assert_eq "URL with space-hash comment stripped" "https://example.com" "$result"

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
fi
