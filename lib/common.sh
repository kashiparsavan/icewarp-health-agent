#!/bin/bash

###############################################################################
#
# Common Library
#
###############################################################################

declare -Ag DATA
declare -Ag STATUS          # per-collector status: ok | error | timeout
declare -Ag STATUS_MSG      # optional error message per collector

TOOL_TIMEOUT="${TOOL_TIMEOUT:-5}"   # seconds, applies to tool.sh / OS command fallback
LOCK_FILE="${LOCK_FILE:-${PROJECT_ROOT}/.agent.lock}"

agent_init() {

    DATA=()
    STATUS=()
    STATUS_MSG=()

    DATA["agent.version"]="${AGENT_VERSION}"
    DATA["agent.hostname"]="$(hostname -f 2>/dev/null || hostname)"
    DATA["agent.time"]="$(date '+%F %T')"

    if [ -n "${COMPANY_NAME:-}" ]; then
        DATA["general.company"]="$COMPANY_NAME"
    fi

}

collector_set() {

    local KEY="$1"
    local VALUE="${2:-}"

    DATA["$KEY"]="$VALUE"

}

###############################################################################
# Locking - prevents overlapping runs (e.g. triggered by cron)
###############################################################################

acquire_lock() {

    if [ -f "$LOCK_FILE" ]; then
        local OLD_PID
        OLD_PID="$(cat "$LOCK_FILE" 2>/dev/null)"

        if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
            echo "[ERROR] Another agent run is already in progress (pid $OLD_PID). Aborting." >&2
            exit 1
        fi

        echo "[WARN] Stale lock file found (pid $OLD_PID not running). Removing." >&2
        rm -f "$LOCK_FILE"
    fi

    echo "$$" > "$LOCK_FILE"

}

release_lock() {
    rm -f "$LOCK_FILE"
}

###############################################################################
# Generic value resolver implementing the priority chain:
#   tool.sh  ->  Config file  ->  OS command
#
# (API/HTTP and SQL layers are not wired in yet - see README/roadmap. They can
#  be added as two extra arguments once WebAdmin API / DB credentials exist.)
#
# Usage:
#   iw_get "<tool.sh property>" "<config file>" "<grep -oP regex>" "<os command>"
#
# Any argument can be passed as "" to skip that layer.
###############################################################################

iw_get() {

    local TOOL_KEY="$1"
    local CONFIG_FILE="$2"
    local CONFIG_REGEX="$3"
    local OS_CMD="$4"
    local VALUE=""

    # 1. tool.sh
    if [ -z "$VALUE" ] && [ -n "$TOOL_KEY" ] && [ -n "${IW_TOOL:-}" ] && [ -x "$IW_TOOL" ]; then
        VALUE="$(iw_tool_get "$TOOL_KEY")"
    fi

    # 2. Config file
    if [ -z "$VALUE" ] && [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ] && [ -n "$CONFIG_REGEX" ]; then
        VALUE="$(grep -oP "$CONFIG_REGEX" "$CONFIG_FILE" 2>/dev/null | head -n1)"
    fi

    # 3. OS command (last resort)
    if [ -z "$VALUE" ] && [ -n "$OS_CMD" ]; then
        VALUE="$(timeout "$TOOL_TIMEOUT" bash -c "$OS_CMD" 2>/dev/null)"
    fi

    printf '%s' "$VALUE"

}

# Low level tool.sh caller, with timeout and output parsing.
# IceWarp's tool.sh typically prints "PropertyName: value"
iw_tool_get() {

    local KEY="$1"
    local RAW

    RAW="$(timeout "$TOOL_TIMEOUT" "$IW_TOOL" display system "$KEY" 2>/dev/null)"

    # Strip CR (Windows-style line endings sometimes appear in tool.sh output)
    RAW="${RAW//$'\r'/}"

    printf '%s' "$RAW" | awk -F': ' '{print $2}' | head -n1

}

###############################################################################
# Collector execution wrapper - called from agent.sh for every collector file.
# Tracks per-collector status so failures are visible in the final report
# instead of silently producing empty fields.
###############################################################################

# NOTE on timeouts: collector_run itself is executed in the *current* shell
# (not a subshell/subprocess) so that collector_set can write into the shared
# DATA array. Wrapping it in `timeout` would lose that shared state. Instead,
# every potentially slow operation (tool.sh calls, OS command fallback) is
# already individually time-bounded inside iw_get/iw_tool_get. A collector
# that only uses iw_get can therefore never hang the whole agent for longer
# than TOOL_TIMEOUT per call. If a collector needs its own long-running OS
# command outside iw_get, it must wrap it with `timeout` itself.
run_collector() {

    local COLLECTOR_PATH="$1"
    local NAME="${COLLECTOR_PATH#$COLLECTOR_DIR/}"
    NAME="${NAME%.sh}"
    local ERR_FILE="/tmp/.collector_err.$$"

    # shellcheck disable=SC1090
    source "$COLLECTOR_PATH"

    if ! declare -F collector_run >/dev/null; then
        unset -f collector_run 2>/dev/null
        return
    fi

    if collector_run 2>"$ERR_FILE"; then
        STATUS["$NAME"]="ok"
    else
        STATUS["$NAME"]="error"
        STATUS_MSG["$NAME"]="$(tail -n1 "$ERR_FILE" 2>/dev/null)"
    fi

    rm -f "$ERR_FILE"
    unset -f collector_run 2>/dev/null

}

list_collectors() {

    find "$COLLECTOR_DIR" -type f -name "*.sh" | \
        sed "s#${COLLECTOR_DIR}/##" | \
        sed 's#\.sh$##' | \
        sort

}

print_report() {

    echo
    echo "========================================"
    echo "IceWarp Health Check Report"
    echo "========================================"
    echo

    for KEY in $(printf "%s\n" "${!DATA[@]}" | sort)
    do
        printf "%-40s : %s\n" "$KEY" "${DATA[$KEY]}"
    done

    echo
    echo "Total Keys : ${#DATA[@]}"

    local FAILED=0
    for NAME in "${!STATUS[@]}"; do
        [ "${STATUS[$NAME]}" != "ok" ] && FAILED=$((FAILED+1))
    done

    if [ "$FAILED" -gt 0 ]; then
        echo
        echo "Collector issues (${FAILED}):"
        for NAME in $(printf "%s\n" "${!STATUS[@]}" | sort); do
            [ "${STATUS[$NAME]}" = "ok" ] && continue
            printf "  [%s] %-30s %s\n" "${STATUS[$NAME]}" "$NAME" "${STATUS_MSG[$NAME]:-}"
        done
    fi

    echo

}
