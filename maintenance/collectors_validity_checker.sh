#!/bin/bash
# ============================================================
# Collectors Validity Checker
# ============================================================
# Usage:
#   ./collectors_validity_checker.sh              # test all collectors + data validation
#   ./collectors_validity_checker.sh <collector>  # test a single collector
#   ./collectors_validity_checker.sh --list       # list all collectors
# ============================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------- Logging ----------
LOG_DIR="${PROJECT_ROOT}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/validity_check_$(date +%Y%m%d_%H%M%S).log"

log() {
    local LEVEL="$1"
    shift
    local MSG="[$(date '+%Y-%m-%d %H:%M:%S')] [$LEVEL] $*"
    echo -e "$MSG" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$@"; }
log_pass() { log "PASS" "$@"; }
log_fail() { log "FAIL" "$@"; }
log_error() { log "ERROR" "$@"; }

# ---------- Helpers ----------
list_collectors() {
    find collectors -type f -name "*.sh" | sed 's/^collectors\///' | sort
}

run_collector_direct() {
    local COLLECTOR_PATH="$1"
    local FULL_PATH="${PROJECT_ROOT}/collectors/${COLLECTOR_PATH}"
    local OUTPUT
    local EXIT_CODE

    OUTPUT=$(timeout 30 bash -c "
        source ${PROJECT_ROOT}/lib/common.sh
        source ${PROJECT_ROOT}/lib/health.sh
        agent_init
        source \"$FULL_PATH\"
        if declare -f collector_run >/dev/null; then
            collector_run
        fi
        for key in \$(printf '%s\n' \"\${!DATA[@]}\" | sort); do
            echo \"\$key=\${DATA[\$key]}\"
        done
    " 2>&1)
    EXIT_CODE=$?

    echo "$OUTPUT"
    return $EXIT_CODE
}

# ---------- Data Validation ----------
validate_data() {
    local JSON_FILE="${PROJECT_ROOT}/output/health.json"
    local EXPECTED_MIN_KEYS="${1:-300}"
    local ACTUAL_KEYS=0

    log_info "Validating data completeness..."

    if [ ! -f "$JSON_FILE" ]; then
        log_error "health.json not found at $JSON_FILE"
        return 1
    fi

    if command -v jq &>/dev/null; then
        ACTUAL_KEYS=$(jq 'keys | length' "$JSON_FILE" 2>/dev/null || echo "0")
    else
        ACTUAL_KEYS=$(grep -o '"[^"]*":' "$JSON_FILE" | wc -l 2>/dev/null || echo "0")
    fi

    ACTUAL_KEYS=$(echo "$ACTUAL_KEYS" | tr -d '[:space:]')
    [ -z "$ACTUAL_KEYS" ] && ACTUAL_KEYS=0

    log_info "Expected minimum keys: $EXPECTED_MIN_KEYS"
    log_info "Actual keys found:     $ACTUAL_KEYS"

    if [ "$ACTUAL_KEYS" -lt "$EXPECTED_MIN_KEYS" ]; then
        log_fail "Data validation FAILED: Only $ACTUAL_KEYS keys found (expected at least $EXPECTED_MIN_KEYS)"
        return 1
    else
        log_pass "Data validation PASSED: $ACTUAL_KEYS keys found"
        return 0
    fi
}

# ---------- Run Agent for Data Validation ----------
run_agent_full() {
    log_info "Running full agent to collect data..."
    
    local AGENT_OUTPUT
    AGENT_OUTPUT=$(./agent.sh --report --technician="ValidityTest" --no-update 2>&1)
    local EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]; then
        log_error "Agent execution failed with exit code $EXIT_CODE"
        echo "$AGENT_OUTPUT" | while IFS= read -r line; do
            [ -n "$line" ] && log_error "  $line"
        done
        return $EXIT_CODE
    fi

    echo "$AGENT_OUTPUT" | while IFS= read -r line; do
        [ -n "$line" ] && log_info "  $line"
    done

    return 0
}

# ---------- Main ----------
if [ "$#" -eq 1 ] && [ "$1" = "--list" ]; then
    list_collectors
    exit 0
fi

if [ "$#" -eq 1 ]; then
    COLLECTOR="$1"
    log_info "Testing single collector: $COLLECTOR"
    
    echo ""
    echo "========================================"
    echo "Collector: $COLLECTOR"
    echo "========================================"
    
    OUTPUT=$(run_collector_direct "$COLLECTOR")
    EXIT_CODE=$?
    
    echo "$OUTPUT"
    echo "========================================"
    echo "Exit code: $EXIT_CODE"
    
    if [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 124 ]; then
        if [ $EXIT_CODE -eq 124 ]; then
            log_error "Collector $COLLECTOR timed out (30s)"
            exit 124
        else
            log_pass "Collector $COLLECTOR passed"
            exit 0
        fi
    else
        log_fail "Collector $COLLECTOR failed with exit code $EXIT_CODE"
        exit 1
    fi
fi

# ---------- Test all collectors ----------
log_info "Starting validity check for all collectors"
log_info "Log file: $LOG_FILE"

COLLECTORS=$(list_collectors)
TOTAL=$(echo "$COLLECTORS" | wc -l)
PASSED=0
FAILED=0
TIMEOUTS=0
FAILED_LIST=""

echo ""
echo "========================================"
echo "Collectors Validity Checker"
echo "========================================"
echo "Started at: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Total collectors: $TOTAL"
echo "Log file: $LOG_FILE"
echo "========================================"
echo ""

log_info "Total collectors found: $TOTAL"

INDEX=0
for C in $COLLECTORS; do
    INDEX=$((INDEX + 1))
    printf "[%3d/%3d] Testing %-45s ... " "$INDEX" "$TOTAL" "$C"
    
    OUTPUT=$(run_collector_direct "$C" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
        log_pass "Collector $C passed"
        PASSED=$((PASSED + 1))
    elif [ $EXIT_CODE -eq 124 ]; then
        echo -e "${RED}TIMEOUT${NC}"
        log_error "Collector $C timed out (30s)"
        TIMEOUTS=$((TIMEOUTS + 1))
        FAILED_LIST="$FAILED_LIST\n  $C (TIMEOUT)"
    else
        echo -e "${RED}FAIL${NC}"
        log_fail "Collector $C failed (exit $EXIT_CODE)"
        FAILED=$((FAILED + 1))
        FAILED_LIST="$FAILED_LIST\n  $C (exit $EXIT_CODE)"
    fi
done

# ---------- Summary ----------
echo ""
echo "========================================"
echo "Collector Execution Summary"
echo "========================================"
echo "Total collectors : $TOTAL"
echo -e "Passed           : ${GREEN}$PASSED${NC}"
echo -e "Failed           : ${RED}$FAILED${NC}"
echo -e "Timed out        : ${RED}$TIMEOUTS${NC}"
echo "========================================"

if [ "$FAILED" -gt 0 ] || [ "$TIMEOUTS" -gt 0 ]; then
    echo ""
    echo "Failed/Timed out collectors:"
    echo -e "$FAILED_LIST"
    log_error "Collector execution completed with $FAILED failed and $TIMEOUTS timed out"
    exit 1
fi

# ---------- Data Validation ----------
echo ""
echo "========================================"
echo "Data Validation"
echo "========================================"

if ! run_agent_full; then
    log_error "Full agent execution failed"
    exit 1
fi

if validate_data 300; then
    echo -e "${GREEN}✅ Data validation PASSED${NC}"
    log_info "All checks passed successfully!"
    exit 0
else
    echo -e "${RED}❌ Data validation FAILED${NC}"
    log_error "Data validation failed! Check logs: $LOG_FILE"
    exit 1
fi
