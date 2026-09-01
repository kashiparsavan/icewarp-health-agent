#!/bin/bash

###############################################################################
#
# Health Rules (M5)
#
# Evaluates the raw values already sitting in DATA[] against thresholds and
# writes pass/warn/fail verdicts back into DATA["health.*"] so the JSON and
# PDF report both get the same evaluated results for free.
#
# Two kinds of thresholds:
#   1. Server-defined  - pulled from IceWarp's own System Monitor config
#      (monitor.memory.alert_below_kb / monitor.disk.alert_below_mb /
#      monitor.cpu.threshold_percent), already collected by
#      collectors/icewarp/system_monitor.sh. If the admin changes those in
#      WebAdmin, this agent automatically follows - no separate config here.
#   2. Hard-coded baselines - security items that don't have a configurable
#      "acceptable" value on the server itself (e.g. weak password policy,
#      DIGEST-MD5 still enabled). These live in HEALTH_* variables below so
#      they're easy to find and adjust in one place.
#
###############################################################################

# --- adjustable baselines for items with no server-side threshold ----------
HEALTH_MIN_PASSWORD_LENGTH="${HEALTH_MIN_PASSWORD_LENGTH:-8}"
HEALTH_MAX_LOGIN_ATTEMPTS="${HEALTH_MAX_LOGIN_ATTEMPTS:-10}"
HEALTH_MIN_DISK_FREE_PERCENT="${HEALTH_MIN_DISK_FREE_PERCENT:-10}"

declare -Ag HEALTH        # rule_name -> pass | warn | fail | skip
declare -Ag HEALTH_MSG    # rule_name -> human readable reason

_health_set() {
    local NAME="$1" RESULT="$2" MSG="${3:-}"
    HEALTH["$NAME"]="$RESULT"
    HEALTH_MSG["$NAME"]="$MSG"
    collector_set "health.${NAME}.result" "$RESULT"
    [ -n "$MSG" ] && collector_set "health.${NAME}.message" "$MSG"
}

_is_num() { [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; }

evaluate_health() {

    # --- Memory: compare live available RAM vs server's own alert floor ---
    local AVAIL_KB="${DATA[os.memory.available_kb]:-}"
    local FLOOR_KB="${DATA[monitor.memory.alert_below_kb]:-}"
    local TOTAL_RAM_KB="${DATA[os.memory.total_kb]:-}"
    if _is_num "$AVAIL_KB" && _is_num "$FLOOR_KB" && [ "$FLOOR_KB" -gt 0 ]; then
        if _is_num "$TOTAL_RAM_KB" && [ "$FLOOR_KB" -gt "$TOTAL_RAM_KB" ]; then
            _health_set "memory" "warn" "Configured alert threshold (${FLOOR_KB}KB) exceeds total installed RAM (${TOTAL_RAM_KB}KB) - this check can never pass as configured; review System Monitor in WebAdmin"
        elif [ "$AVAIL_KB" -lt "$FLOOR_KB" ]; then
            _health_set "memory" "fail" "Available memory (${AVAIL_KB}KB) is below the server's configured alert threshold (${FLOOR_KB}KB)"
        else
            _health_set "memory" "pass" "Available memory (${AVAIL_KB}KB) is above threshold (${FLOOR_KB}KB)"
        fi
    else
        _health_set "memory" "skip" "System Monitor memory threshold not configured on server"
    fi

    # --- Disk: compare each collected mount's free space vs server floor --
    # Dedupe by device+mountpoint first - on single-partition installs,
    # storage.archive / storage.install / storage.mail / storage.root_fs /
    # storage.root_home often all resolve to the SAME physical filesystem,
    # and evaluating each label independently made one under-threshold disk
    # count as N separate failures in the summary. Only the first label seen
    # per unique device+mount gets a real verdict; the rest are cross-linked.
    local DISK_FLOOR_MB="${DATA[monitor.disk.alert_below_mb]:-}"
    local MOUNT_KEY MOUNT_NAME FREE_GB FREE_MB TOTAL_GB TOTAL_MB DEVICE MOUNT DEDUPE_KEY WORST="pass"
    declare -A _SEEN_DISK=()
    for MOUNT_KEY in "${!DATA[@]}"; do
        [[ "$MOUNT_KEY" == storage.*.free_gb ]] || continue
        MOUNT_NAME="${MOUNT_KEY#storage.}"
        MOUNT_NAME="${MOUNT_NAME%.free_gb}"
        DEVICE="${DATA[storage.${MOUNT_NAME}.device]:-}"
        MOUNT="${DATA[storage.${MOUNT_NAME}.mount]:-}"
        DEDUPE_KEY="${DEVICE}|${MOUNT}"

        if [ -n "${_SEEN_DISK[$DEDUPE_KEY]:-}" ]; then
            # Same physical filesystem as an already-evaluated label - link
            # to it instead of re-running (and re-failing) the same check.
            collector_set "health.disk.${MOUNT_NAME}.result" "same_as:${_SEEN_DISK[$DEDUPE_KEY]}"
            continue
        fi
        _SEEN_DISK["$DEDUPE_KEY"]="$MOUNT_NAME"

        FREE_GB="${DATA[$MOUNT_KEY]}"
        _is_num "$FREE_GB" || continue
        FREE_MB="$(awk -v g="$FREE_GB" 'BEGIN{printf "%d", g*1024}')"
        TOTAL_GB="${DATA[storage.${MOUNT_NAME}.total_gb]:-}"

        if ! _is_num "$DISK_FLOOR_MB" || [ "$DISK_FLOOR_MB" -le 0 ]; then
            _health_set "disk.${MOUNT_NAME}" "skip" "System Monitor disk threshold not configured on server"
            continue
        fi

        if _is_num "$TOTAL_GB"; then
            TOTAL_MB="$(awk -v g="$TOTAL_GB" 'BEGIN{printf "%d", g*1024}')"
            if [ "$DISK_FLOOR_MB" -gt "$TOTAL_MB" ]; then
                _health_set "disk.${MOUNT_NAME}" "warn" "Configured alert threshold (${DISK_FLOOR_MB}MB) exceeds total disk capacity (${TOTAL_MB}MB) - this check can never pass as configured; review System Monitor in WebAdmin"
                [ "$WORST" = "pass" ] && WORST="warn"
                continue
            fi
        fi

        if [ "$FREE_MB" -lt "$DISK_FLOOR_MB" ]; then
            _health_set "disk.${MOUNT_NAME}" "fail" "Free space (${FREE_GB}GB) below configured alert threshold"
            WORST="fail"
        else
            _health_set "disk.${MOUNT_NAME}" "pass" "Free space (${FREE_GB}GB) OK"
        fi
    done
    collector_set "health.disk.overall" "$WORST"

    # --- CPU load vs server's own alert threshold (approximate: load1 vs cores * threshold%) ---
    local LOAD1="${DATA[os.cpu.load1]:-}"
    local CORES="${DATA[os.cpu.count]:-}"
    local CPU_PCT="${DATA[monitor.cpu.threshold_percent]:-}"
    if _is_num "$LOAD1" && _is_num "$CORES" && _is_num "$CPU_PCT" && [ "$CORES" -gt 0 ]; then
        local LIMIT
        LIMIT="$(awk -v c="$CORES" -v p="$CPU_PCT" 'BEGIN{printf "%.2f", c*p/100}')"
        if awk -v l="$LOAD1" -v lim="$LIMIT" 'BEGIN{exit !(l>lim)}'; then
            _health_set "cpu" "warn" "1-min load (${LOAD1}) exceeds threshold approximation (${LIMIT})"
        else
            _health_set "cpu" "pass" "1-min load (${LOAD1}) within threshold approximation (${LIMIT})"
        fi
    else
        _health_set "cpu" "skip" "System Monitor CPU threshold not configured, or load/core data missing"
    fi

    # --- Password policy baseline ---
    local PW_ACTIVE="${DATA[security.password_policy.active]:-}"
    local PW_MIN="${DATA[security.password_policy.min_length]:-}"
    if [ "$PW_ACTIVE" = "1" ] && _is_num "$PW_MIN"; then
        if [ "$PW_MIN" -lt "$HEALTH_MIN_PASSWORD_LENGTH" ]; then
            _health_set "password_policy" "warn" "Password policy active but min length (${PW_MIN}) is below recommended ${HEALTH_MIN_PASSWORD_LENGTH}"
        else
            _health_set "password_policy" "pass" "Password policy active, min length ${PW_MIN} meets recommendation"
        fi
    else
        _health_set "password_policy" "fail" "Password policy is not active"
    fi

    # --- Login blocking: two separate IceWarp features can provide this -
    # "Login Policy" (account-level lockout) and "Intrusion Prevention ->
    # Block IP after failed logins" (IP-level blocking). They're independent
    # toggles. Previously this only looked at max_failed_attempts and never
    # checked whether Login Policy was actually enabled, which could report
    # "pass" even when that policy was off. Now it checks both mechanisms
    # and passes if EITHER is genuinely active.
    local POLICY_ENABLED="${DATA[security.login.policy_enabled]:-}"
    local LOGIN_MAX="${DATA[security.login.max_failed_attempts]:-}"
    local INTRUSION_ENABLED="${DATA[security.intrusion.block_failed_logins.enabled]:-}"
    local INTRUSION_VAL="${DATA[security.intrusion.block_failed_logins.value]:-}"

    if [ "$POLICY_ENABLED" = "1" ] && _is_num "$LOGIN_MAX" && [ "$LOGIN_MAX" -gt 0 ]; then
        if [ "$LOGIN_MAX" -gt "$HEALTH_MAX_LOGIN_ATTEMPTS" ]; then
            _health_set "login_blocking" "warn" "Login Policy lockout threshold (${LOGIN_MAX}) is higher than recommended (${HEALTH_MAX_LOGIN_ATTEMPTS})"
        else
            _health_set "login_blocking" "pass" "Login Policy lockout active, threshold (${LOGIN_MAX}) OK"
        fi
    elif [ "$INTRUSION_ENABLED" = "1" ] && _is_num "$INTRUSION_VAL" && [ "$INTRUSION_VAL" -gt 0 ]; then
        _health_set "login_blocking" "pass" "Login Policy lockout is off, but Intrusion Prevention blocks the IP after ${INTRUSION_VAL} failed logins"
    else
        _health_set "login_blocking" "fail" "Neither Login Policy lockout nor Intrusion Prevention failed-login blocking is active"
    fi

    # --- TLS/SSL delivery ---
    if [ "${DATA[smtp.use_tls_ssl]:-}" = "1" ]; then
        _health_set "tls_delivery" "pass" "TLS/SSL for delivery is enabled"
    else
        _health_set "tls_delivery" "fail" "TLS/SSL for delivery is NOT enabled"
    fi

    # --- DIGEST-MD5 should be disabled ---
    if [ "${DATA[security.digest_md5.enabled]:-}" = "true" ]; then
        _health_set "digest_md5" "warn" "DIGEST-MD5 auth scheme is still enabled (weak, legacy)"
    elif [ "${DATA[security.digest_md5.enabled]:-}" = "false" ]; then
        _health_set "digest_md5" "pass" "DIGEST-MD5 auth scheme is disabled"
    else
        _health_set "digest_md5" "skip" "Auth scheme list not available"
    fi

    # --- Backup ran recently (best effort: just checks it's enabled + has a last_time) ---
    if [ "${DATA[icewarp.backup.auto_enabled]:-}" = "1" ] && [ -n "${DATA[icewarp.backup.last_time]:-}" ]; then
        _health_set "backup" "pass" "Automatic backup enabled, last run: ${DATA[icewarp.backup.last_time]}"
    else
        _health_set "backup" "fail" "Automatic backup not enabled or never ran"
    fi

    # --- Roll-up ---
    local TOTAL=0 FAIL=0 WARN=0
    for K in "${!HEALTH[@]}"; do
        [ "${HEALTH[$K]}" = "skip" ] && continue
        TOTAL=$((TOTAL+1))
        [ "${HEALTH[$K]}" = "fail" ] && FAIL=$((FAIL+1))
        [ "${HEALTH[$K]}" = "warn" ] && WARN=$((WARN+1))
    done

    collector_set "health.summary.total_checks" "$TOTAL"
    collector_set "health.summary.failed" "$FAIL"
    collector_set "health.summary.warnings" "$WARN"

    if [ "$FAIL" -gt 0 ]; then
        collector_set "health.summary.overall" "fail"
    elif [ "$WARN" -gt 0 ]; then
        collector_set "health.summary.overall" "warn"
    else
        collector_set "health.summary.overall" "pass"
    fi

}
