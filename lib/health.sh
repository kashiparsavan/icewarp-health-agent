#!/bin/bash

###############################################################################
#
# Health Rules (M5)
#
###############################################################################

HEALTH_MIN_PASSWORD_LENGTH="${HEALTH_MIN_PASSWORD_LENGTH:-8}"
HEALTH_MAX_LOGIN_ATTEMPTS="${HEALTH_MAX_LOGIN_ATTEMPTS:-10}"
HEALTH_MIN_DISK_FREE_PERCENT="${HEALTH_MIN_DISK_FREE_PERCENT:-10}"

declare -Ag HEALTH
declare -Ag HEALTH_MSG

_health_set() {
    local NAME="$1" RESULT="$2" MSG="${3:-}"
    HEALTH["$NAME"]="$RESULT"
    HEALTH_MSG["$NAME"]="$MSG"
    collector_set "health.${NAME}.result" "$RESULT"
    [ -n "$MSG" ] && collector_set "health.${NAME}.message" "$MSG"
}

_is_num() { [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; }

_days_ago() {
    local date_str="$1"
    [[ -z "$date_str" ]] && echo "999"
    local date_epoch=$(date -d "$date_str" +%s 2>/dev/null)
    [[ -z "$date_epoch" ]] && echo "999"
    echo $(( ( $(date +%s) - date_epoch ) / 86400 ))
}

evaluate_health() {

    # --- Memory ---
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

    # --- Disk ---
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

    # --- CPU ---
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

    # --- Password policy ---
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

    # --- Login blocking ---
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

    # --- DIGEST-MD5 ---
    if [ "${DATA[security.digest_md5.enabled]:-}" = "true" ]; then
        _health_set "digest_md5" "warn" "DIGEST-MD5 auth scheme is still enabled (weak, legacy)"
    elif [ "${DATA[security.digest_md5.enabled]:-}" = "false" ]; then
        _health_set "digest_md5" "pass" "DIGEST-MD5 auth scheme is disabled"
    else
        _health_set "digest_md5" "skip" "Auth scheme list not available"
    fi

    # --- Backup ---
    if [ "${DATA[icewarp.backup.auto_enabled]:-}" = "1" ] && [ -n "${DATA[icewarp.backup.last_time]:-}" ]; then
        _health_set "backup" "pass" "Automatic backup enabled, last run: ${DATA[icewarp.backup.last_time]}"
    else
        _health_set "backup" "fail" "Automatic backup not enabled or never ran"
    fi

    # --- OS Last Update ---
    local LAST_UPDATE="${DATA[os.last_update_date]:-}"
    if [ -n "$LAST_UPDATE" ] && [ "$LAST_UPDATE" != "N/A" ] && [ "$LAST_UPDATE" != "null" ]; then
        local DAYS=$(_days_ago "$LAST_UPDATE")
        if [ "$DAYS" -gt 14 ]; then
            _health_set "os_update" "fail" "OS last update was $DAYS days ago (threshold: 14 days)"
        elif [ "$DAYS" -gt 7 ]; then
            _health_set "os_update" "warn" "OS last update was $DAYS days ago (threshold: 7 days)"
        else
            _health_set "os_update" "pass" "OS last update was $DAYS days ago (OK)"
        fi
    else
        _health_set "os_update" "skip" "OS last update date not available"
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
