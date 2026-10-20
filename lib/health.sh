#!/bin/bash

###############################################################################
#
# Health Rules (M5) - Refactored with correct keys
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

_health_worst() {
    local WORST="pass" ANY=0 R
    for R in "$@"; do
        case "$R" in
            fail|critical) printf 'fail'; return ;;
            warn) WORST="warn"; ANY=1 ;;
            pass|info) ANY=1 ;;
        esac
    done
    if [ "$ANY" -eq 0 ]; then printf 'skip'; else printf '%s' "$WORST"; fi
}

_health_messages_for() {
    local RESULT="$1"; shift
    local -a MSGS=()
    local K R M
    for K in "$@"; do
        R="${HEALTH[$K]:-skip}"
        [ "$R" = "critical" ] && R="fail"
        [ "$R" = "$RESULT" ] || continue
        M="${HEALTH_MSG[$K]:-}"
        [ -n "$M" ] && MSGS+=("$M")
    done
    local IFS='; '
    printf '%s' "${MSGS[*]}"
}

evaluate_health() {

    # --- Memory (percentage based) ---
    local AVAIL_KB="${DATA[os.memory.available_kb]:-}"
    local TOTAL_RAM_KB="${DATA[os.memory.total_kb]:-}"
    if _is_num "$AVAIL_KB" && _is_num "$TOTAL_RAM_KB" && [ "$TOTAL_RAM_KB" -gt 0 ]; then
        local USED_PERCENT=$(awk -v t="$TOTAL_RAM_KB" -v a="$AVAIL_KB" 'BEGIN{printf "%.2f", ((t-a)/t)*100}')
        if awk -v used="$USED_PERCENT" -v lim=90 'BEGIN{exit !(used > lim)}'; then
            _health_set "memory" "critical" "RAM usage is ${USED_PERCENT}% (CRITICAL - above 90%)"
        elif awk -v used="$USED_PERCENT" -v lim=40 'BEGIN{exit !(used > lim)}'; then
            _health_set "memory" "warn" "RAM usage is ${USED_PERCENT}% (WARN - above 40%)"
        else
            _health_set "memory" "pass" "RAM usage is ${USED_PERCENT}% (OK)"
        fi
    else
        _health_set "memory" "skip" "Unable to calculate RAM usage"
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
            _health_set "disk.${MOUNT_NAME}" "skip" "System Monitor disk threshold not configured"
            continue
        fi

        if _is_num "$TOTAL_GB"; then
            TOTAL_MB="$(awk -v g="$TOTAL_GB" 'BEGIN{printf "%d", g*1024}')"
            if [ "$DISK_FLOOR_MB" -gt "$TOTAL_MB" ]; then
                _health_set "disk.${MOUNT_NAME}" "warn" "Configured threshold (${DISK_FLOOR_MB}MB) exceeds capacity (${TOTAL_MB}MB) - review System Monitor"
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
    if [ "$WORST" = "fail" ]; then
        _health_set "disk.overall" "fail" "One or more monitored disks are below the configured free-space threshold"
    elif [ "$WORST" = "warn" ]; then
        _health_set "disk.overall" "warn" "Disk alert thresholds need review"
    else
        _health_set "disk.overall" "pass" "All monitored disks have adequate free space"
    fi

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
        _health_set "cpu" "skip" "System Monitor CPU threshold missing or load/core data unavailable"
    fi

    # --- Password policy ---
    local PW_ACTIVE="${DATA[security.password_policy.active]:-}"
    local PW_MIN="${DATA[security.password_policy.min_length]:-}"
    if [ "$PW_ACTIVE" = "1" ] && _is_num "$PW_MIN"; then
        if [ "$PW_MIN" -lt "$HEALTH_MIN_PASSWORD_LENGTH" ]; then
            _health_set "password_policy" "warn" "Password policy active but min length (${PW_MIN}) below recommended ${HEALTH_MIN_PASSWORD_LENGTH}"
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
            _health_set "login_blocking" "warn" "Login Policy lockout threshold (${LOGIN_MAX}) higher than recommended (${HEALTH_MAX_LOGIN_ATTEMPTS})"
        else
            _health_set "login_blocking" "pass" "Login Policy lockout active, threshold (${LOGIN_MAX}) OK"
        fi
    elif [ "$INTRUSION_ENABLED" = "1" ] && _is_num "$INTRUSION_VAL" && [ "$INTRUSION_VAL" -gt 0 ]; then
        _health_set "login_blocking" "pass" "Login Policy lockout is off, but Intrusion Prevention blocks IP after ${INTRUSION_VAL} failed logins"
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

    # --- Backup (using icewarp.* and backup.db.* keys) ---
    local AUTO_ENABLED="${DATA[icewarp.backup.auto_enabled]:-0}"
    local LAST_TIME="${DATA[icewarp.backup.last_time]:-}"
    
    # Individual database backup statuses (from new collectors)
    local DB_ACCOUNTS="${DATA[backup.db.accounts.enabled]:-0}"
    local DB_AS="${DATA[backup.db.as.enabled]:-0}"
    local DB_GW="${DATA[backup.db.gw.enabled]:-0}"
    local DB_CACHE="${DATA[backup.db.cache.enabled]:-0}"

    # Main backup enable
    if [ "$AUTO_ENABLED" = "1" ]; then
        _health_set "backup.auto" "pass" "Automatic system backup is enabled"
    else
        _health_set "backup.auto" "critical" "Automatic system backup is DISABLED (required for production)"
    fi

    # Overall database backup: PASS if at least Accounts is enabled (core DB)
    if [ "$DB_ACCOUNTS" = "1" ]; then
        _health_set "backup.db" "pass" "Database backup is enabled (Accounts)"
    else
        _health_set "backup.db" "critical" "Database backup is DISABLED (Accounts missing)"
    fi

    # Individual database backup statuses (for detailed reporting)
    if [ "$DB_ACCOUNTS" = "1" ]; then
        _health_set "backup.db.accounts" "pass" "Accounts database backup is enabled"
    else
        _health_set "backup.db.accounts" "critical" "Accounts database backup is DISABLED"
    fi

    if [ "$DB_AS" = "1" ]; then
        _health_set "backup.db.as" "pass" "Anti-Spam database backup is enabled"
    else
        _health_set "backup.db.as" "critical" "Anti-Spam database backup is DISABLED"
    fi

    if [ "$DB_GW" = "1" ]; then
        _health_set "backup.db.gw" "pass" "GroupWare database backup is enabled"
    else
        _health_set "backup.db.gw" "critical" "GroupWare database backup is DISABLED"
    fi

    # Directory Cache is optional – informational only
    if [ "$DB_CACHE" = "1" ]; then
        _health_set "backup.db.cache" "info" "Directory Cache database backup is enabled (optional)"
    else
        _health_set "backup.db.cache" "info" "Directory Cache database backup is disabled (optional)"
    fi

    # Last backup time
    if [ -n "$LAST_TIME" ] && [ "$LAST_TIME" != "null" ] && [ "$LAST_TIME" != "N/A" ]; then
        local DAYS=$(_days_ago "$LAST_TIME")
        if [ "$DAYS" -lt 2 ]; then
            _health_set "backup.last_time" "pass" "Last backup run: $LAST_TIME ($DAYS days ago)"
        elif [ "$DAYS" -lt 7 ]; then
            _health_set "backup.last_time" "warn" "Last backup run: $LAST_TIME ($DAYS days ago) - consider recent backup"
        else
            _health_set "backup.last_time" "critical" "Last backup run: $LAST_TIME ($DAYS days ago) - too old"
        fi
    else
        _health_set "backup.last_time" "warn" "No backup history found (manual run never executed)"
    fi

    # --- Watchdog (main enable + individual services) ---
    local CONTROL="${DATA[watchdog.control]:-0}"
    local SMTP="${DATA[watchdog.smtp]:-0}"
    local POP3="${DATA[watchdog.pop3]:-0}"
    local IM="${DATA[watchdog.im]:-0}"
    local GW="${DATA[watchdog.gw]:-0}"
    local INTERVAL="${DATA[watchdog.interval_minutes]:-0}"

    # Main watchdog enable
    if [ "$CONTROL" = "1" ]; then
        _health_set "watchdog.control" "pass" "System Watchdog is ENABLED"
    else
        _health_set "watchdog.control" "critical" "System Watchdog is DISABLED"
    fi

    # Individual services
    if [ "$SMTP" = "1" ]; then
        _health_set "watchdog.smtp" "pass" "SMTP Watchdog is ENABLED"
    else
        _health_set "watchdog.smtp" "critical" "SMTP Watchdog is DISABLED"
    fi

    if [ "$POP3" = "1" ]; then
        _health_set "watchdog.pop3" "pass" "POP3/IMAP Watchdog is ENABLED"
    else
        _health_set "watchdog.pop3" "critical" "POP3/IMAP Watchdog is DISABLED"
    fi

    if [ "$IM" = "1" ]; then
        _health_set "watchdog.im" "pass" "IM/VoIP Watchdog is ENABLED"
    else
        _health_set "watchdog.im" "critical" "IM/VoIP Watchdog is DISABLED"
    fi

    if [ "$GW" = "1" ]; then
        _health_set "watchdog.gw" "pass" "GroupWare Watchdog is ENABLED"
    else
        _health_set "watchdog.gw" "critical" "GroupWare Watchdog is DISABLED"
    fi

    # Watchdog interval
    if [ "$INTERVAL" -eq 0 ]; then
        _health_set "watchdog.interval" "pass" "Interval: Every minute (0) - optimal"
    elif [ "$INTERVAL" -ge 1 ] && [ "$INTERVAL" -le 60 ]; then
        _health_set "watchdog.interval" "pass" "Interval: ${INTERVAL} minutes (optimal)"
    elif [ "$INTERVAL" -gt 60 ] && [ "$INTERVAL" -le 1440 ]; then
        _health_set "watchdog.interval" "warn" "Interval: ${INTERVAL} minutes (more than 1 hour - consider reducing)"
    else
        _health_set "watchdog.interval" "critical" "Interval: ${INTERVAL} minutes (too long or invalid)"
    fi

    # --- System Monitor ---
    local MONITOR_ENABLED="${DATA[monitor.enabled]:-0}"
    if [ "$MONITOR_ENABLED" = "1" ]; then
        local CPU_TH="${DATA[monitor.cpu.threshold_percent]:-50}"
        local MEM_TH="${DATA[monitor.memory.alert_below_kb]:-1048576}"
        local DISK_TH="${DATA[monitor.disk.alert_below_mb]:-5120}"
        _health_set "monitor.enabled" "pass" "System Monitor ENABLED (CPU>${CPU_TH}% | RAM<${MEM_TH}KB | DISK<${DISK_TH}MB)"
    else
        _health_set "monitor.enabled" "critical" "System Monitor is DISABLED"
    fi

    # --- OS Last Update ---
    local LAST_UPDATE="${DATA[os.last_update_date]:-}"
    if [ -n "$LAST_UPDATE" ] && [ "$LAST_UPDATE" != "N/A" ] && [ "$LAST_UPDATE" != "null" ]; then
        local DAYS=$(_days_ago "$LAST_UPDATE")
        if [ "$DAYS" -le 7 ]; then
            _health_set "os_update" "pass" "OS updated recently (${DAYS} days ago)"
        elif [ "$DAYS" -le 30 ]; then
            _health_set "os_update" "warn" "OS update is ${DAYS} days old (consider updating within a week)"
        else
            _health_set "os_update" "critical" "OS is outdated (${DAYS} days since last update)"
        fi
    else
        _health_set "os_update" "skip" "OS last update date not available"
    fi

    # --- Directory Cache Schedule ---
    local CACHE_SCHED="${DATA[directory_cache.schedule_raw]:-}"
    if [ -z "$CACHE_SCHED" ] || [ "$CACHE_SCHED" = "not scheduled" ] || [ "$CACHE_SCHED" = "null" ]; then
        _health_set "directory_cache" "critical" "Directory Cache schedule is NOT SET or failed to parse"
    else
        _health_set "directory_cache" "pass" "Directory Cache schedule is configured (${CACHE_SCHED})"
    fi

    # --- Report Health Summary roll-ups ---
    # The technical and management reports show nine executive pillars rather
    # than every low-level rule. Each pillar is derived from the detailed
    # checks above so the summary reflects the overall service, not one metric.

    # Backup & recovery
    local BKP_RES BKP_MSG
    BKP_RES="$(_health_worst "${HEALTH[backup.auto]:-skip}" "${HEALTH[backup.db]:-skip}" "${HEALTH[backup.last_time]:-skip}")"
    BKP_MSG="$(_health_messages_for "$BKP_RES" backup.auto backup.db backup.last_time)"
    [ -z "$BKP_MSG" ] && BKP_MSG="System, database and recent-backup checks are in place"
    _health_set "backup" "$BKP_RES" "$BKP_MSG"

    # Mail flow & DNS
    local MF_RES="pass" MF_ANY=0 MF_SPEC MF_KEY MF_LABEL MF_SEV MF_VAL
    local -a MF_ISSUES=()
    for MF_SPEC in \
        "dns.spf.found|SPF record|fail" \
        "dns.dkim.found|DKIM record|fail" \
        "dns.dmarc.found|DMARC record|warn" \
        "dns.ptr.exists|PTR record|warn" \
        "smtp.starttls_live_test|STARTTLS|fail" \
        "dns.lookup_test.ok|DNS lookup|fail"
    do
        IFS='|' read -r MF_KEY MF_LABEL MF_SEV <<< "$MF_SPEC"
        MF_VAL="${DATA[$MF_KEY]:-}"
        [ -z "$MF_VAL" ] && continue
        MF_ANY=1
        if [ "$MF_VAL" != "true" ] && [ "$MF_VAL" != "1" ]; then
            MF_ISSUES+=("$MF_LABEL")
            if [ "$MF_SEV" = "fail" ]; then
                MF_RES="fail"
            elif [ "$MF_RES" != "fail" ]; then
                MF_RES="warn"
            fi
        fi
    done
    if [ "${DATA[dns.ptr.exists]:-}" = "true" ] && [ "${DATA[dns.ptr.matches_hostname]:-}" = "false" ]; then
        MF_ISSUES+=("PTR does not match the mail hostname")
        [ "$MF_RES" != "fail" ] && MF_RES="warn"
    fi
    if [ "${DATA[dns.spf.found]:-}" = "true" ] && [ "${DATA[dns.spf.includes_server_ip]:-}" = "false" ]; then
        MF_ISSUES+=("SPF does not include this server's IP")
        [ "$MF_RES" != "fail" ] && MF_RES="warn"
    fi
    if [ "$MF_ANY" -eq 0 ]; then
        _health_set "mail_flow" "skip" "Mail-flow DNS and STARTTLS checks did not return data"
    elif [ "${#MF_ISSUES[@]}" -gt 0 ]; then
        local MF_JOINED
        MF_JOINED="$(IFS=', '; printf '%s' "${MF_ISSUES[*]}")"
        _health_set "mail_flow" "$MF_RES" "Needs attention: ${MF_JOINED}"
    else
        _health_set "mail_flow" "pass" "SPF, DKIM, DMARC, PTR and STARTTLS checks passed"
    fi

    # Transport security (delivery TLS + certificate expiry)
    local TLS_RES="${HEALTH[tls_delivery]:-skip}"
    local TLS_MSG="${HEALTH_MSG[tls_delivery]:-}"
    local CERT_DAYS="${DATA[icewarp.ssl.days_left]:-}"
    if _is_num "$CERT_DAYS"; then
        if [ "$CERT_DAYS" -lt 0 ]; then
            TLS_RES="fail"
            TLS_MSG="The TLS certificate has expired"
        elif [ "$CERT_DAYS" -lt 30 ]; then
            TLS_RES="fail"
            TLS_MSG="The TLS certificate expires in ${CERT_DAYS} days"
        elif [ "$CERT_DAYS" -lt 90 ]; then
            [ "$TLS_RES" != "fail" ] && TLS_RES="warn"
            TLS_MSG="${TLS_MSG}; certificate expires in ${CERT_DAYS} days"
        elif [ "$TLS_RES" = "pass" ]; then
            TLS_MSG="TLS delivery is enabled; certificate valid for ${CERT_DAYS} days"
        fi
    else
        [ -n "$TLS_MSG" ] && TLS_MSG="${TLS_MSG}; certificate expiry unavailable"
        [ -z "$TLS_MSG" ] && TLS_MSG="TLS certificate expiry is not available"
    fi
    [ -z "$TLS_MSG" ] && TLS_MSG="TLS delivery and certificate validity are in order"
    _health_set "tls" "$TLS_RES" "$TLS_MSG"

    # Access & authentication
    local ACC_RES ACC_MSG
    ACC_RES="$(_health_worst "${HEALTH[login_blocking]:-skip}" "${HEALTH[password_policy]:-skip}" "${HEALTH[digest_md5]:-skip}")"
    ACC_MSG="$(_health_messages_for "$ACC_RES" login_blocking password_policy digest_md5)"
    local TWOFA_RAW="${DATA[security.login.2fa_bypass_enabled]:-}"
    if [[ "$TWOFA_RAW" == "1" ]] || [[ "$TWOFA_RAW" == "true" ]] || [[ "$TWOFA_RAW" == "TRUE" ]] || [[ "$TWOFA_RAW" == "True" ]]; then
        [ "$ACC_RES" = "pass" ] || [ "$ACC_RES" = "skip" ] && ACC_RES="warn"
        ACC_MSG="${ACC_MSG}${ACC_MSG:+; }2FA bypass is enabled"
    fi
    [ -z "$ACC_MSG" ] && ACC_MSG="Login lockout, password policy and authentication controls are in order"
    _health_set "access" "$ACC_RES" "$ACC_MSG"

    # Threat protection (definitions freshness + RBL)
    local TH_RES="pass" TH_ANY=0 TH_DAYS TH_DATE
    local -a TH_ISSUES=()
    TH_DATE="${DATA[icewarp.antispam.last_update]:-}"
    if [ -n "$TH_DATE" ] && [ "$TH_DATE" != "N/A" ] && [ "$TH_DATE" != "null" ]; then
        TH_ANY=1
        TH_DAYS="$(_days_ago "$TH_DATE")"
        if [ "$TH_DAYS" -gt 30 ]; then
            TH_RES="fail"; TH_ISSUES+=("antispam definitions are ${TH_DAYS} days old")
        elif [ "$TH_DAYS" -gt 7 ]; then
            [ "$TH_RES" != "fail" ] && TH_RES="warn"; TH_ISSUES+=("antispam definitions are ${TH_DAYS} days old")
        fi
    else
        TH_ANY=1; [ "$TH_RES" != "fail" ] && TH_RES="warn"; TH_ISSUES+=("antispam update date unavailable")
    fi
    TH_DATE="${DATA[icewarp.antivirus.last_update]:-}"
    if [ -n "$TH_DATE" ] && [ "$TH_DATE" != "N/A" ] && [ "$TH_DATE" != "null" ]; then
        TH_ANY=1
        TH_DAYS="$(_days_ago "$TH_DATE")"
        if [ "$TH_DAYS" -gt 30 ]; then
            TH_RES="fail"; TH_ISSUES+=("antivirus definitions are ${TH_DAYS} days old")
        elif [ "$TH_DAYS" -gt 7 ]; then
            [ "$TH_RES" != "fail" ] && TH_RES="warn"; TH_ISSUES+=("antivirus definitions are ${TH_DAYS} days old")
        fi
    else
        TH_ANY=1; [ "$TH_RES" != "fail" ] && TH_RES="warn"; TH_ISSUES+=("antivirus update date unavailable")
    fi
    if [ "${DATA[security.rbl_self_check.checked]:-}" = "true" ]; then
        TH_ANY=1
        if [ "${DATA[security.rbl_self_check.listed]:-}" = "true" ]; then
            TH_RES="fail"
            TH_ISSUES+=("server IP is listed on ${DATA[security.rbl_self_check.listed_on]:-an RBL}")
        fi
    fi
    if [ "${DATA[security.cyren_folder.status]:-}" = "WARN" ]; then
        TH_ANY=1
        [ "$TH_RES" != "fail" ] && TH_RES="warn"
        TH_ISSUES+=("old AntiSpam folders need cleanup")
    fi
    if [ "$TH_ANY" -eq 0 ]; then
        _health_set "threat" "skip" "Threat-protection freshness could not be determined"
    elif [ "${#TH_ISSUES[@]}" -gt 0 ]; then
        local TH_JOINED
        TH_JOINED="$(IFS=', '; printf '%s' "${TH_ISSUES[*]}")"
        _health_set "threat" "$TH_RES" "Needs attention: ${TH_JOINED}"
    else
        _health_set "threat" "pass" "Antispam and antivirus definitions are current; IP is not listed on the checked RBLs"
    fi

    # Server resources
    local RES_RES RES_MSG
    RES_RES="$(_health_worst "${HEALTH[memory]:-skip}" "${HEALTH[cpu]:-skip}" "${HEALTH[disk.overall]:-skip}")"
    if [ "$RES_RES" = "pass" ]; then
        RES_MSG="CPU, RAM and disk headroom are within configured thresholds"
    else
        RES_MSG="$(_health_messages_for "$RES_RES" memory cpu disk.overall)"
        [ -z "$RES_MSG" ] && RES_MSG="One or more resource thresholds need attention"
    fi
    _health_set "resources" "$RES_RES" "$RES_MSG"

    # Monitoring & watchdog
    local MON_RES MON_MSG
    MON_RES="$(_health_worst "${HEALTH[monitor.enabled]:-skip}" "${HEALTH[watchdog.control]:-skip}" "${HEALTH[watchdog.interval]:-skip}")"
    if [ "$MON_RES" = "pass" ]; then
        MON_MSG="System Monitor, Watchdog and the watchdog interval are configured"
    else
        MON_MSG="$(_health_messages_for "$MON_RES" monitor.enabled watchdog.control watchdog.interval)"
        [ -z "$MON_MSG" ] && MON_MSG="Monitoring or watchdog coverage is incomplete"
    fi
    _health_set "monitoring" "$MON_RES" "$MON_MSG"

    # Database platform
    local DB_TYPE="${DATA[database.type]:-}"
    local DB_RES="skip" DB_MSG="Database type could not be determined"
    case "$DB_TYPE" in
        sqlite)
            DB_RES="warn"
            DB_MSG="SQLite is in use; MySQL is recommended for production"
            ;;
        mysql)
            if [ "${DATA[mysql.applicable]:-false}" = "true" ] && [ "${DATA[mysql.service_active]:-1}" != "1" ]; then
                DB_RES="fail"
                DB_MSG="MySQL is configured but the database service is not active"
            elif [ "${DATA[database.scope]:-}" = "remote" ] && [ "${DATA[mysql.reachable]:-1}" != "1" ]; then
                DB_RES="fail"
                DB_MSG="Remote MySQL is not reachable on port 3306"
            else
                DB_RES="pass"
                DB_MSG="MySQL database platform is active"
            fi
            ;;
        unknown|"")
            DB_RES="skip"
            DB_MSG="Database type could not be determined"
            ;;
        *)
            DB_RES="warn"
            DB_MSG="Unrecognised database type: ${DB_TYPE}"
            ;;
    esac
    _health_set "database" "$DB_RES" "$DB_MSG"

    # --- Roll-up (nine executive pillars) ---
    local TOTAL=0 FAIL=0 WARN=0

    local -a SUMMARY_KEYS=(
        backup
        mail_flow
        tls
        access
        threat
        resources
        os_update
        monitoring
        database
    )

    for K in "${SUMMARY_KEYS[@]}"; do
        local RES="${HEALTH[$K]:-skip}"
        [ "$RES" = "skip" ] && continue
        TOTAL=$((TOTAL+1))
        [ "$RES" = "fail" ] || [ "$RES" = "critical" ] && FAIL=$((FAIL+1))
        [ "$RES" = "warn" ] && WARN=$((WARN+1))
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
