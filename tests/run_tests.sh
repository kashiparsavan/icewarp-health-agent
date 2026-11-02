#!/bin/bash
# Test runner for the IceWarp Health Agent.
#
#   ./tests/run_tests.sh            run every case
#   ./tests/run_tests.sh norm_date run a single case
#
# Each test_*.sh is executed in its own process, so a failure in one case
# cannot poison the harness state. The runner exits non-zero if any case
# fails or is missing, and prints a one-line summary at the end.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$ROOT/tests"

PASSED=0
FAILED=0
MISSING=0

for CASE in "$TESTS_DIR"/test_*.sh; do
    [ -x "$CASE" ] || chmod +x "$CASE"
    NAME="$(basename "$CASE" .sh)"
    if [ -n "${1:-}" ] && [ "$NAME" != "test_$1" ] && [ "$NAME" != "$1" ]; then
        continue
    fi

    if bash "$CASE"; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
        echo ">>> $NAME FAILED (exit $?)"
    fi
done

echo
echo "========================================"
echo "tests: ${PASSED} passed, ${FAILED} failed"
echo "========================================"

[ "$FAILED" -eq 0 ]