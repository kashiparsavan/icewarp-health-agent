#!/bin/bash
# norm_date: the single shared date normaliser (lib/common.sh).
# It must accept ISO, IceWarp D-M-YY and Windows M/D/YYYY, and must refuse
# anything else - GNU `date -d` must never see a raw IceWarp string.

source "$(dirname "$0")/lib.sh"

echo "=== norm_date ==="

# Accepts
assert_eq "ISO with time" "2026-10-28" "$(norm_date "2026-10-28 02:01:18")"
assert_eq "IceWarp D-M-YY" "2026-10-27" "$(norm_date "27-10-26")"
assert_eq "IceWarp D-M-YY two digit year" "2026-10-27" "$(norm_date "27-10-26")"
assert_eq "Windows M/D/YYYY" "2026-10-25" "$(norm_date "10/25/2026")"
assert_eq "Windows D/M/YYYY (first field > 12)" "2026-10-25" "$(norm_date "25/10/2026")"
assert_eq "ISO bare" "2026-10-28" "$(norm_date "2026-10-28")"
assert_eq "strips quotes" "2026-10-28" "$(norm_date '"2026-10-28"')"

# The classic bug this guards against: "9-8-26" must NOT become 0009-08-26.
BAD="$(norm_date "9-8-26" 2>/dev/null || echo "unparseable")"
if [ "$BAD" = "unparseable" ]; then
    echo "ok   - '9-8-26' is unparseable (not year 0009)"
else
    echo "FAIL - '9-8-26' parsed as '$BAD' (should be unparseable)"
    TESTS_FAILED=1
fi

# Rejects
if norm_date "" >/dev/null 2>&1; then
    echo "FAIL - empty string should be rejected"; TESTS_FAILED=1
else echo "ok   - empty string rejected"; fi

if norm_date "not-a-date" >/dev/null 2>&1; then
    echo "FAIL - 'not-a-date' should be rejected"; TESTS_FAILED=1
else echo "ok   - 'not-a-date' rejected"; fi

if norm_date "2026-13-45" >/dev/null 2>&1; then
    echo "FAIL - '2026-13-45' should be rejected"; TESTS_FAILED=1
else echo "ok   - '2026-13-45' rejected"; fi

# _days_ago prints nothing (and returns 1) for an unparseable date; callers
# must treat that as "unknown", never as 0.
DAYS="$(_days_ago "not-a-date" 2>/dev/null || true)"
if [ -z "$DAYS" ]; then
    echo "ok   - _days_ago prints nothing for unparseable date"
else
    echo "FAIL - _days_ago printed '$DAYS' for an unparseable date"; TESTS_FAILED=1
fi

DAYS="$(_days_ago "2026-10-28" || true)"
if _is_num "$DAYS" && [ "$DAYS" -ge 0 ]; then
    echo "ok   - _days_ago('2026-10-28') = ${DAYS}"
else
    echo "FAIL - _days_ago('2026-10-28') = '${DAYS}'"; TESTS_FAILED=1
fi

exit "$TESTS_FAILED"