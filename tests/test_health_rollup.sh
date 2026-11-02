#!/bin/bash
# evaluate_health pillar roll-ups and health.summary.* from a sample DATA[].
# Two fixtures: a healthy server and one whose root filesystem is full. The
# roll-up must be truthful in both directions - one failing disk must flip the
# resources pillar and the executive overall to fail.

source "$(dirname "$0")/lib.sh"

run_fixture() {
    local FIX="$1"
    # evaluate_health writes into HEALTH[] and DATA[health.*]; reset both.
    HEALTH=(); HEALTH_MSG=(); HEALTH_EXPECTED=(); HEALTH_ACTUAL=(); HEALTH_DISPLAY=()
    load_fixture "$FIX"
    evaluate_health
}

echo "=== evaluate_health roll-ups ==="

run_fixture "$TEST_ROOT/tests/fixtures/healthy.dat"

assert_eq "healthy: backup" "pass" "${HEALTH[backup]:-skip}"
assert_eq "healthy: mail_flow" "pass" "${HEALTH[mail_flow]:-skip}"
assert_eq "healthy: tls" "pass" "${HEALTH[tls]:-skip}"
assert_eq "healthy: access" "pass" "${HEALTH[access]:-skip}"
assert_eq "healthy: threat" "pass" "${HEALTH[threat]:-skip}"
assert_eq "healthy: resources" "pass" "${HEALTH[resources]:-skip}"
assert_eq "healthy: os_update" "pass" "${HEALTH[os_update]:-skip}"
assert_eq "healthy: monitoring" "pass" "${HEALTH[monitoring]:-skip}"
assert_eq "healthy: database" "pass" "${HEALTH[database]:-skip}"
assert_eq "healthy: overall" "pass" "${DATA[health.summary.overall]:-skip}"
assert_eq "healthy: failed count" "0" "${DATA[health.summary.failed]:-0}"
assert_eq "healthy: warnings" "0" "${DATA[health.summary.warnings]:-0}"
assert_eq "healthy: total_checks > 0" "1" "$([ "${DATA[health.summary.total_checks]:-0}" -gt 0 ] && echo 1 || echo 0)"

# A full disk must flip resources AND the executive overall.
run_fixture "$TEST_ROOT/tests/fixtures/disk_full.dat"
assert_eq "full disk: disk.overall" "fail" "${HEALTH[disk.overall]:-skip}"
assert_eq "full disk: resources" "fail" "${HEALTH[resources]:-skip}"
assert_eq "full disk: overall" "fail" "${DATA[health.summary.overall]:-skip}"
assert_eq "full disk: failed count" "1" "${DATA[health.summary.failed]:-0}"

# Missing-data semantics: a key that was never collected must NOT be reported
# as pass with an invented default.
unset DATA[monitor.enabled] DATA[watchdog.interval_minutes] DATA[security.login.2fa_bypass_enabled]
HEALTH=(); HEALTH_MSG=(); HEALTH_EXPECTED=(); HEALTH_ACTUAL=(); HEALTH_DISPLAY=()
load_fixture "$TEST_ROOT/tests/fixtures/disk_full.dat"
evaluate_health
assert_eq "missing monitor.enabled -> warn" "warn" "${HEALTH[monitor.enabled]:-skip}"
assert_eq "missing watchdog.interval -> warn" "warn" "${HEALTH[watchdog.interval]:-skip}"
assert_eq "missing 2FA -> skip" "skip" "${HEALTH[access.2fa]:-skip}"

# Deterministic disk de-duplication: the same DATA[] must produce the same
# result twice in a row (sorted keys, numeric-safe comparisons).
run_fixture "$TEST_ROOT/tests/fixtures/disk_full.dat"
FIRST="${HEALTH[disk.overall]}|${DATA[health.summary.overall]}"
run_fixture "$TEST_ROOT/tests/fixtures/disk_full.dat"
SECOND="${HEALTH[disk.overall]}|${DATA[health.summary.overall]}"
assert_eq "disk roll-up is deterministic" "$FIRST" "$SECOND"

# total_checks counts evaluated registry checks, not pillars, so the cover
# text "X checks run across Y areas" is truthful.
TC="${DATA[health.summary.total_checks]:-0}"
AR="${DATA[health.summary.areas_assessed]:-0}"
if [ "$TC" -ge "$AR" ] && [ "$AR" -ge 1 ]; then
    echo "ok   - total_checks($TC) >= areas_assessed($AR)"
else
    echo "FAIL - total_checks($TC) < areas_assessed($AR)"; TESTS_FAILED=1
fi

exit "$TESTS_FAILED"