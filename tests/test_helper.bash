# Shared test helper — loaded by all .bats files
# BATS_TEST_FILENAME is e.g. /path/to/repo/tests/bats/foo.bats
# We need the repo root (two levels up from the .bats file)
TESTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

load "${TESTS_DIR}/libs/bats-support/load"
load "${TESTS_DIR}/libs/bats-assert/load"
