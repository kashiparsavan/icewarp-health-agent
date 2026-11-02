#!/bin/bash
# Shared test harness. Sourced by every test case.
#
# The tests exercise the agent's own libraries (lib/common.sh, lib/health.sh,
# lib/json.sh) against canned fixtures, so a passing test means the shipped
# code behaves as documented - not a re-implementation of it.
#
# Network access and IceWarp tool.sh are NOT used: iw_get/iw_tool_get are
# stubbed out so a fixture is the only input.

# Absolute path to the repository root (tests/ lives one level below it).
TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TEST_ROOT

# Stubs for the IceWarp tool. The collectors call these; the unit tests never
# do, but sourcing common.sh must not blow up on a machine without tool.sh.
IW_TOOL=""
iw_tool_get() { printf ''; }
iw_tool_get_multiline() { printf ''; }
iw_get() { printf ''; }
iw_get_domain() { printf ''; }
iw_list_domains() { return 0; }

# A fixture is a flat "key value" file (one per line, '#' comments allowed).
# load_fixture <path> populates the shared DATA[] associative array.
load_fixture() {
    local FILE="$1" KEY VAL LINE
    while IFS= read -r LINE || [ -n "$LINE" ]; do
        LINE="${LINE%%#*}"
        [ -z "${LINE//[[:space:]]/}" ] && continue
        KEY="${LINE%% *}"
        VAL="${LINE#* }"
        DATA["$KEY"]="$VAL"
    done < "$FILE"
}

# assert_eq <label> <expected> <actual>
assert_eq() {
    local LABEL="$1" EXPECTED="$2" ACTUAL="$3"
    if [ "$EXPECTED" = "$ACTUAL" ]; then
        echo "ok   - $LABEL"
    else
        echo "FAIL - $LABEL (expected '$EXPECTED', got '$ACTUAL')"
        TESTS_FAILED=1
    fi
}

# assert_contains <label> <needle> <haystack>
assert_contains() {
    local LABEL="$1" NEEDLE="$2" HAYSTACK="$3"
    case "$HAYSTACK" in
        *"$NEEDLE"*) echo "ok   - $LABEL" ;;
        *) echo "FAIL - $LABEL (expected to contain '$NEEDLE', got '$HAYSTACK')"; TESTS_FAILED=1 ;;
    esac
}

# Source the agent libraries once. health.sh re-declares HEALTH/HEALTH_MSG as
# associative arrays, so it must be sourced after common.sh.
source "$TEST_ROOT/lib/common.sh"
source "$TEST_ROOT/lib/health.sh"
source "$TEST_ROOT/lib/json.sh"

TESTS_FAILED=0