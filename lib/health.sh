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
declare -Ag HEALTH_EXPECTED
declare -Ag HEALTH_ACTUAL
declare -Ag HEALTH_DISPLAY

# _health_set <name> <result> [message] [expected] [actual] [display]
# expected/actual feed health.v2.json checks[]; display is the human value the
# PDF renderers show in the "Value" column (falls back to actual). None of the
# three is written to DATA[], so the flat key set only gains health.<id>.* keys.
_health_set() {
    local NAME="$1" RESULT="$2" MSG="${3:-}" EXP="${4:-}" ACT="${5:-}" DSP="${6:-}"
    HEALTH["$NAME"]="$RESULT"
    HEALTH_MSG["$NAME"]="$MSG"
    [ -n "$EXP" ] && HEALTH_EXPECTED["$NAME"]="$EXP"
    [ -n "$ACT" ] && HEALTH_ACTUAL["$NAME"]="$ACT"
    [ -n "$DSP" ] && HEALTH_DISPLAY["$NAME"]="$DSP"
    collector_set "health.${NAME}.result" "$RESULT"
    [ -n "$MSG" ] && collector_set "health.${NAME}.message" "$MSG"
}

_is_num() { [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; }

# _days_ago / norm_date live in lib/common.sh (single copy)

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


###############################################################################
# Check registry: the single source of truth for pillar membership.
#   line = id|pillar|title|flags      flags (comma separated):
#     d   = detail only, shown but NOT rolled into its pillar
#     opt = optional feature (pass either way, never rolled up)
#     p   = the check IS the pillar (os_update)
# Pillar roll-ups, health.v2.json checks[] and the PDF/management statuses all
# derive from this table. A new check = one line here + one _health_set call.
###############################################################################
HEALTH_PILLARS=(backup mail_flow tls access threat resources os_update monitoring database)

HEALTH_REGISTRY_LINES=(
    "backup.auto|backup|Automatic system backup|"
    "backup.db|backup|Database backup|"
    "backup.db.accounts|backup|Accounts database backup|d"
    "backup.db.as|backup|Anti-Spam database backup|d"
    "backup.db.gw|backup|GroupWare database backup|d"
    "backup.db.cache|backup|Directory Cache database backup|opt"
    "backup.last_time|backup|Last backup run|"
    "mail.spf|mail_flow|SPF record|"
    "mail.dkim|mail_flow|DKIM record|"
    "mail.dmarc|mail_flow|DMARC record|"
    "mail.ptr|mail_flow|PTR record|"
    "mail.starttls|mail_flow|STARTTLS|"
    "mail.dns_lookup|mail_flow|DNS lookup|"
    "dnsbl_zones|mail_flow|DNSBL zones|"
    "service.imap|mail_flow|IMAP service|"
    "service.pop3|mail_flow|POP3 service|"
    "smtp.threads|mail_flow|SMTP simultaneous threads|d"
    "tls_delivery|tls|TLS/SSL for delivery|"
    "tls.certificate|tls|TLS certificate expiry|"
    "login_blocking|access|Login blocking|"
    "password_policy|access|Password policy|"
    "digest_md5|access|DIGEST-MD5 disabled|"
    "admin_email|access|Admin email|"
    "session_timeout|access|Session timeout|"
    "access.2fa|access|Two-factor authentication|"
    "threat.antispam|threat|Anti-Spam definitions|"
    "threat.antivirus|threat|Anti-Virus definitions|"
    "threat.rbl|threat|Server IP not blacklisted|"
    "threat.cyren|threat|Old AntiSpam folders|"
    "intrusion.block_connections|threat|Intrusion: connections per minute|"
    "intrusion.unknown_user|threat|Intrusion: unknown user count|"
    "intrusion.relay_denied|threat|Intrusion: relay denied count|"
    "intrusion.rset|threat|Intrusion: RSET session count|"
    "intrusion.spam_score|threat|Intrusion: message spam score|"
    "intrusion.failed_logins|threat|Intrusion: failed login attempts|"
    "intrusion.block_duration|threat|Intrusion: block duration|"
    "memory|resources|Memory|"
    "cpu|resources|CPU|"
    "disk.overall|resources|Disk space|"
    "swap|resources|Swap usage|d"
    "os_update|os_update|OS last update|p"
    "monitor.enabled|monitoring|System Monitor|"
    "watchdog.control|monitoring|Watchdog|"
    "watchdog.smtp|monitoring|SMTP watchdog|"
    "watchdog.pop3|monitoring|POP3/IMAP watchdog|"
    "watchdog.im|monitoring|IM/VoIP watchdog|"
    "watchdog.gw|monitoring|GroupWare watchdog|"
    "watchdog.interval|monitoring|Watchdog interval|"
    "database.platform|database|Database platform|"
    "directory_cache|database|Directory Cache schedule|"
)

declare -Ag HEALTH_REGISTRY=()
declare -Ag HEALTH_PILLAR_OK=(
    [backup]="System, database and recent-backup checks are in place"
    [mail_flow]="SPF, DKIM, DMARC, PTR, STARTTLS, DNSBL and mail services are in order"
    [tls]="TLS delivery is enabled and the certificate is valid"
    [access]="Login lockout, password policy and authentication controls are in order"
    [threat]="Antispam and antivirus definitions are current, intrusion prevention is tuned and the IP is not listed on the checked RBLs"
    [resources]="CPU, RAM and disk headroom are within configured thresholds"
    [os_update]="OS is up to date"
    [monitoring]="System Monitor, Watchdog (all services) and the watchdog interval are configured"
    [database]="Database platform and Directory Cache schedule are in order"
)
declare -Ag HEALTH_PILLAR_SKIP=(
    [mail_flow]="Mail-flow DNS and STARTTLS checks did not return data"
    [threat]="Threat-protection freshness could not be determined"
)
_hl=""
for _hl in "${HEALTH_REGISTRY_LINES[@]}"; do HEALTH_REGISTRY["${_hl%%|*}"]="${_hl#*|}"; done
unset _hl

# PDF / management-report row label -> check id (labels from config/checklist.conf.pdf)
declare -Ag HEALTH_LABEL_MAP=(
    ["Enable System Backup"]="backup.auto"
    ["Enable Database Backup"]="backup.db"
    ["Enable Database Backup - Accounts"]="backup.db.accounts"
    ["Enable Database Backup - AntiSpam"]="backup.db.as"
    ["Enable Database Backup - GroupWare"]="backup.db.gw"
    ["Enable Database Backup - Directory Cache"]="backup.db.cache"
    ["Last Backup Date and Time"]="backup.last_time"
    ["Check for Certificates"]="tls.certificate"
    ["2FA"]="access.2fa"
    ["Set Admin Email"]="admin_email"
    ["Session Timeout"]="session_timeout"
    ["Disable DIGEST-MD5"]="digest_md5"
    ["Disable IMAP"]="service.imap"
    ["Disable POP3"]="service.pop3"
    ["Maximum Number of Simultaneous Threads"]="smtp.threads"
    ["Remove Old AntiSpam Folders"]="threat.cyren"
    ["Block IP - Connections in 1 Minute"]="intrusion.block_connections"
    ["Block IP - Unknown User Delivery Count"]="intrusion.unknown_user"
    ["Block IP - Denied for Relaying Too Often"]="intrusion.relay_denied"
    ["Block IP - Exceeds RSET Session Count"]="intrusion.rset"
    ["Block IP - Message Spam Score"]="intrusion.spam_score"
    ["Block IP - Exceeds Failed Login Attempts"]="intrusion.failed_logins"
    ["Amount of Time IP is Blocked (minutes)"]="intrusion.block_duration"
    ["Enable System Watchdog"]="watchdog.control"
    ["Watchdog - SMTP"]="watchdog.smtp"
    ["Watchdog - POP3/IMAP"]="watchdog.pop3"
    ["Watchdog - IM/VoIP"]="watchdog.im"
    ["Watchdog - GroupWare"]="watchdog.gw"
    ["Watchdog Interval"]="watchdog.interval"
    ["Enable System Monitor (Mem/Disk/CPU)"]="monitor.enabled"
    ["Set Directory Cache Schedule"]="directory_cache"
    ["Database Type"]="database.platform"
    ["Disk (Total GB / Used %)"]="disk.overall"
    ["CPU Usage"]="cpu"
    ["RAM (Total KB / Available KB)"]="memory"
    ["APP OS Last Update"]="os_update"
    ["Swap Usage (7 days)"]="swap"
)

# health_meta <id>  -> "pillar|title|flags" (per-mount disks fall back to resources)
health_meta() {
    local ID="$1"
    if [ -n "${HEALTH_REGISTRY[$ID]:-}" ]; then printf '%s' "${HEALTH_REGISTRY[$ID]}"
    elif [[ "$ID" == disk.* ]]; then printf 'resources|Disk %s|d' "${ID#disk.}"
    fi
}

# health_rolled_up <id> -> exit 0 when the check feeds its pillar
health_rolled_up() {
    local META FLAGS
    META="$(health_meta "$1")"; FLAGS=",${META##*|},"
    [ -n "$META" ] && [[ "$FLAGS" != *,d,* && "$FLAGS" != *,opt,* ]]
}

# health_kind <id> -> PASS | WARN | CRITICAL | INFO (skip) for the PDF renderers
health_kind() {
    case "${HEALTH[$1]:-skip}" in
        pass) printf 'PASS' ;;
        warn) printf 'WARN' ;;
        fail|critical) printf 'CRITICAL' ;;
        *) printf 'INFO' ;;
    esac
}

# health_row_for_label <label> [checklist note]
# Sets HR_KIND / HR_VALUE / HR_NOTE for a mapped checklist row and returns 0;
# returns 1 when the label has no health check. The PDFs hold no thresholds.
health_row_for_label() {
    local LABEL="$1" CL_NOTE="${2:-}" ID="${HEALTH_LABEL_MAP[$1]:-}"
    [ -n "$ID" ] || return 1
    HR_KIND="$(health_kind "$ID")"
    HR_VALUE="${HEALTH_DISPLAY[$ID]:-${HEALTH_ACTUAL[$ID]:-}}"
    if [ "$HR_KIND" = "INFO" ]; then HR_VALUE="${HR_VALUE:-N/A}"; fi
    [ -z "$HR_VALUE" ] && HR_VALUE="$HR_KIND"
    if [ "$HR_KIND" = "PASS" ]; then HR_NOTE="${CL_NOTE:-${HEALTH_MSG[$ID]:-}}"
    else HR_NOTE="${HEALTH_MSG[$ID]:-$CL_NOTE}"; fi
    return 0
}

# _pillar_rollup <pillar>: worst result of the pillar's rolled-up checks
_pillar_rollup() {
    local P="$1" L ID PILLAR TITLE FLAGS RES MSG
    local -a IDS=() RESULTS=()
    for L in "${HEALTH_REGISTRY_LINES[@]}"; do
        IFS='|' read -r ID PILLAR TITLE FLAGS <<< "$L"
        [ "$PILLAR" = "$P" ] || continue
        [[ ",${FLAGS}," == *,d,* || ",${FLAGS}," == *,opt,* || ",${FLAGS}," == *,p,* ]] && continue
        IDS+=("$ID"); RESULTS+=("${HEALTH[$ID]:-skip}")
    done
    RES="$(_health_worst "${RESULTS[@]}")"
    case "$RES" in
        pass) MSG="${HEALTH_PILLAR_OK[$P]:-All checks passed}" ;;
        skip) MSG="${HEALTH_PILLAR_SKIP[$P]:-No data available for this area}" ;;
        *)    MSG="$(_health_messages_for "$RES" "${IDS[@]}")"
              [ -z "$MSG" ] && MSG="One or more checks need attention" ;;
    esac
    _health_set "$P" "$RES" "$MSG"
}

# _health_bool <id> <raw> <bad_result> <pass_msg> <bad_msg> <good_word> <bad_word>
_health_bool() {
    local ID="$1" RAW="$2" BAD="$3" PM="$4" BM="$5" GW="$6" BW="$7"
    if [ "$RAW" = "1" ] || [ "$RAW" = "true" ]; then
        _health_set "$ID" "pass" "$PM" "$GW" "$GW" "$GW"
    else
        _health_set "$ID" "$BAD" "$BM" "$GW" "$BW" "$BW"
    fi
}

# _health_age <id> <date> <label> <pass_max_days> <warn_max_days> <result_beyond_warn>
_health_age() {
    local ID="$1" DATE="$2" LABEL="$3" PASS_MAX="$4" WARN_MAX="$5" BAD="$6" DAYS
    DAYS="$(_days_ago "$DATE")"
    if [ -z "$DAYS" ]; then
        _health_set "$ID" "warn" "${LABEL} date could not be parsed: ${DATE}" "<=${PASS_MAX} days" "" "$DATE"
    elif [ "$DAYS" -le "$PASS_MAX" ]; then
        _health_set "$ID" "pass" "${LABEL} is ${DAYS} days old" "<=${PASS_MAX} days" "$DAYS" "${DATE} (${DAYS} days ago)"
    elif [ "$DAYS" -le "$WARN_MAX" ]; then
        _health_set "$ID" "warn" "${LABEL} is ${DAYS} days old (expected <= ${PASS_MAX})" "<=${PASS_MAX} days" "$DAYS" "${DATE} (${DAYS} days ago)"
    else
        _health_set "$ID" "$BAD" "${LABEL} is ${DAYS} days old (expected <= ${PASS_MAX})" "<=${PASS_MAX} days" "$DAYS" "${DATE} (${DAYS} days ago)"
    fi
}

# _health_expect <id> <label> <data_key> <expected> [numeric]
# Missing -> critical, different -> warn, equal -> pass (CLAUDE.md 3.5).
_health_expect() {
    local ID="$1" LABEL="$2" VAL="${DATA[$3]:-}" EXPD="$4" SAME=0
    if [ -z "$VAL" ]; then
        _health_set "$ID" "critical" "${LABEL} setting not found" "$EXPD" "" "not found"
        return
    fi
    if [ "$VAL" = "$EXPD" ]; then SAME=1
    elif _is_num "$VAL" && _is_num "$EXPD" && awk -v a="$VAL" -v b="$EXPD" 'BEGIN{exit !(a==b)}'; then SAME=1; fi
    if [ "$SAME" -eq 1 ]; then
        _health_set "$ID" "pass" "${LABEL} is ${VAL} (expected ${EXPD})" "$EXPD" "$VAL" "$VAL"
    else
        _health_set "$ID" "warn" "${LABEL} is ${VAL} (expected ${EXPD})" "$EXPD" "$VAL" "$VAL"
    fi
}

evaluate_health() {

    # --- Memory (percentage based) ---
    # Display value format (STRICT): Total(KB)=<total> / Available KB=<available>
    local AVAIL_KB="${DATA[os.memory.available_kb]:-}"
    local TOTAL_RAM_KB="${DATA[os.memory.total_kb]:-}"
    local RAM_NOTE="Total(KB)=${TOTAL_RAM_KB:-0} / Available KB=${AVAIL_KB:-0}"
    local USED_PERCENT
    if _is_num "$AVAIL_KB" && _is_num "$TOTAL_RAM_KB" && [ "$TOTAL_RAM_KB" -gt 0 ]; then
        USED_PERCENT=$(awk -v t="$TOTAL_RAM_KB" -v a="$AVAIL_KB" 'BEGIN{printf "%.2f", ((t-a)/t)*100}')
        if awk -v used="$USED_PERCENT" -v lim=90 'BEGIN{exit !(used > lim)}'; then
            _health_set "memory" "critical" "RAM usage ${USED_PERCENT}% (critical above 90%)" "<=40% used" "$USED_PERCENT" "$RAM_NOTE"
        elif awk -v used="$USED_PERCENT" -v lim=40 'BEGIN{exit !(used > lim)}'; then
            _health_set "memory" "warn" "RAM usage ${USED_PERCENT}% (warn above 40%)" "<=40% used" "$USED_PERCENT" "$RAM_NOTE"
        else
            _health_set "memory" "pass" "RAM usage ${USED_PERCENT}%" "<=40% used" "$USED_PERCENT" "$RAM_NOTE"
        fi
    else
        _health_set "memory" "warn" "RAM usage could not be calculated" "<=40% used" "" "$RAM_NOTE"
    fi

    # --- Disk ---
    # Display value format (STRICT): Total(GB)=<total> / Used %=<used>
    local DISK_FLOOR_MB="${DATA[monitor.disk.alert_below_mb]:-}"
    local MOUNT_KEY MOUNT_NAME FREE_GB FREE_MB TOTAL_GB TOTAL_MB DEVICE MOUNT DEDUPE_KEY WORST="pass"
    local DISK_EXPECT=""
    _is_num "$DISK_FLOOR_MB" && DISK_EXPECT=">=${DISK_FLOOR_MB} MB free"
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
        USED_PERCENT="${DATA[storage.${MOUNT_NAME}.used_percent]:-}"
        local DISK_NOTE="Total(GB)=${TOTAL_GB:-0} / Used %=${USED_PERCENT:-0}"

        if ! _is_num "$DISK_FLOOR_MB" || [ "$DISK_FLOOR_MB" -le 0 ]; then
            _health_set "disk.${MOUNT_NAME}" "warn" "System Monitor disk threshold is not set" "" "$FREE_MB" "$DISK_NOTE"
            [ "$WORST" = "pass" ] && WORST="warn"
            continue
        fi

        if _is_num "$TOTAL_GB"; then
            TOTAL_MB="$(awk -v g="$TOTAL_GB" 'BEGIN{printf "%d", g*1024}')"
            if [ "$DISK_FLOOR_MB" -gt "$TOTAL_MB" ]; then
                _health_set "disk.${MOUNT_NAME}" "warn" "Disk alert threshold (${DISK_FLOOR_MB} MB) is larger than the disk" "$DISK_EXPECT" "$FREE_MB" "$DISK_NOTE"
                [ "$WORST" = "pass" ] && WORST="warn"
                continue
            fi
        fi

        if [ "$FREE_MB" -lt "$DISK_FLOOR_MB" ]; then
            _health_set "disk.${MOUNT_NAME}" "fail" "Free space ${FREE_MB} MB is below the ${DISK_FLOOR_MB} MB threshold" "$DISK_EXPECT" "$FREE_MB" "$DISK_NOTE"
            WORST="fail"
        else
            _health_set "disk.${MOUNT_NAME}" "pass" "Free space ${FREE_MB} MB (threshold ${DISK_FLOOR_MB} MB)" "$DISK_EXPECT" "$FREE_MB" "$DISK_NOTE"
        fi
    done
    local ROOT_NOTE="Total(GB)=${DATA[storage.root_fs.total_gb]:-0} / Used %=${DATA[storage.root_fs.used_percent]:-0}"
    if [ "$WORST" = "fail" ]; then
        _health_set "disk.overall" "fail" "One or more monitored disks are below the configured free-space threshold" "$DISK_EXPECT" "" "$ROOT_NOTE"
    elif [ "$WORST" = "warn" ]; then
        _health_set "disk.overall" "warn" "Disk alert thresholds need review" "$DISK_EXPECT" "" "$ROOT_NOTE"
    else
        _health_set "disk.overall" "pass" "All monitored disks have adequate free space" "$DISK_EXPECT" "" "$ROOT_NOTE"
    fi

    # --- CPU ---
    local LOAD1="${DATA[os.cpu.load1]:-}"
    local CORES="${DATA[os.cpu.count]:-}"
    local CPU_PCT="${DATA[monitor.cpu.threshold_percent]:-}"
    if _is_num "$LOAD1" && _is_num "$CORES" && _is_num "$CPU_PCT" && [ "$CORES" -gt 0 ]; then
        local LIMIT
        LIMIT="$(awk -v c="$CORES" -v p="$CPU_PCT" 'BEGIN{printf "%.2f", c*p/100}')"
        if awk -v l="$LOAD1" -v lim="$LIMIT" 'BEGIN{exit !(l>lim)}'; then
            _health_set "cpu" "warn" "1-min load (${LOAD1}) exceeds threshold approximation (${LIMIT})" "<=${LIMIT}" "$LOAD1" "load1 ${LOAD1} (limit ${LIMIT})"
        else
            _health_set "cpu" "pass" "1-min load (${LOAD1}) within threshold approximation (${LIMIT})" "<=${LIMIT}" "$LOAD1" "load1 ${LOAD1} (limit ${LIMIT})"
        fi
    else
        _health_set "cpu" "skip" "System Monitor CPU threshold missing or load/core data unavailable"
    fi

    # --- Swap (detail only: collector status, never rolled into resources) ---
    local SWAP_STATUS="${DATA[system.swap.status]:-}"
    local SWAP_MSG="${DATA[system.swap.message]:-Swap status: ${SWAP_STATUS}}"
    local SWAP_DSP="${DATA[system.swap.used_percent]:-0}%"
    case "$SWAP_STATUS" in
        PASS)     _health_set "swap" "pass" "$SWAP_MSG" "PASS" "$SWAP_STATUS" "$SWAP_DSP" ;;
        CRITICAL) _health_set "swap" "critical" "$SWAP_MSG" "PASS" "$SWAP_STATUS" "$SWAP_DSP" ;;
        "")       _health_set "swap" "skip" "Swap status not available" ;;
        *)        _health_set "swap" "warn" "$SWAP_MSG" "PASS" "$SWAP_STATUS" "$SWAP_DSP" ;;
    esac

    # --- Password policy ---
    local PW_ACTIVE="${DATA[security.password_policy.active]:-}"
    local PW_MIN="${DATA[security.password_policy.min_length]:-}"
    if [ "$PW_ACTIVE" = "1" ] && _is_num "$PW_MIN"; then
        if [ "$PW_MIN" -lt "$HEALTH_MIN_PASSWORD_LENGTH" ]; then
            _health_set "password_policy" "warn" "Password policy active but min length (${PW_MIN}) below recommended ${HEALTH_MIN_PASSWORD_LENGTH}" ">=${HEALTH_MIN_PASSWORD_LENGTH}" "$PW_MIN"
        else
            _health_set "password_policy" "pass" "Password policy active, min length ${PW_MIN} meets recommendation" ">=${HEALTH_MIN_PASSWORD_LENGTH}" "$PW_MIN"
        fi
    else
        _health_set "password_policy" "fail" "Password policy is not active" "active" "inactive"
    fi

    # --- Login blocking ---
    local POLICY_ENABLED="${DATA[security.login.policy_enabled]:-}"
    local LOGIN_MAX="${DATA[security.login.max_failed_attempts]:-}"
    local INTRUSION_ENABLED="${DATA[security.intrusion.block_failed_logins.enabled]:-}"
    local INTRUSION_VAL="${DATA[security.intrusion.block_failed_logins.value]:-}"

    if [ "$POLICY_ENABLED" = "1" ] && _is_num "$LOGIN_MAX" && [ "$LOGIN_MAX" -gt 0 ]; then
        if [ "$LOGIN_MAX" -gt "$HEALTH_MAX_LOGIN_ATTEMPTS" ]; then
            _health_set "login_blocking" "warn" "Login Policy lockout threshold (${LOGIN_MAX}) higher than recommended (${HEALTH_MAX_LOGIN_ATTEMPTS})" "<=${HEALTH_MAX_LOGIN_ATTEMPTS}" "$LOGIN_MAX"
        else
            _health_set "login_blocking" "pass" "Login Policy lockout active, threshold (${LOGIN_MAX}) OK" "<=${HEALTH_MAX_LOGIN_ATTEMPTS}" "$LOGIN_MAX"
        fi
    elif [ "$INTRUSION_ENABLED" = "1" ] && _is_num "$INTRUSION_VAL" && [ "$INTRUSION_VAL" -gt 0 ]; then
        _health_set "login_blocking" "pass" "Login Policy lockout is off, but Intrusion Prevention blocks IP after ${INTRUSION_VAL} failed logins" "<=${HEALTH_MAX_LOGIN_ATTEMPTS}" "$INTRUSION_VAL"
    else
        _health_set "login_blocking" "fail" "Neither Login Policy lockout nor Intrusion Prevention failed-login blocking is active" "<=${HEALTH_MAX_LOGIN_ATTEMPTS}" "off"
    fi

    # --- TLS/SSL delivery ---
    _health_bool "tls_delivery" "${DATA[smtp.use_tls_ssl]:-}" "fail" \
        "TLS/SSL for delivery is enabled" "TLS/SSL for delivery is NOT enabled" "Enabled" "Disabled"

    # --- TLS certificate expiry: <0 expired, <30 fail, <90 warn ---
    local CERT_DAYS="${DATA[icewarp.ssl.days_left]:-}"
    local CERT_EXP="${DATA[icewarp.ssl.expiration]:-}"
    if _is_num "$CERT_DAYS" && [ -n "$CERT_EXP" ] && [ "$CERT_EXP" != "N/A" ] && [ "$CERT_EXP" != "not returned" ]; then
        local CERT_DSP="expires ${CERT_EXP} (${CERT_DAYS} days left)"
        if [ "$CERT_DAYS" -lt 0 ]; then
            _health_set "tls.certificate" "fail" "The TLS certificate has expired" ">=90 days" "$CERT_DAYS" "$CERT_DSP"
        elif [ "$CERT_DAYS" -lt 30 ]; then
            _health_set "tls.certificate" "fail" "The TLS certificate expires in ${CERT_DAYS} days" ">=90 days" "$CERT_DAYS" "$CERT_DSP"
        elif [ "$CERT_DAYS" -lt 90 ]; then
            _health_set "tls.certificate" "warn" "The TLS certificate expires in ${CERT_DAYS} days" ">=90 days" "$CERT_DAYS" "$CERT_DSP"
        else
            _health_set "tls.certificate" "pass" "The TLS certificate is valid for ${CERT_DAYS} days" ">=90 days" "$CERT_DAYS" "$CERT_DSP"
        fi
    else
        _health_set "tls.certificate" "skip" "TLS certificate expiry is not available"
    fi

    # --- DIGEST-MD5 (Strict Override: true=CRITICAL (enabled=bad), false=PASS (disabled=good), missing=CRITICAL) ---
    local DIGEST_RAW="${DATA[security.digest_md5.enabled]:-}"
    if [ "$DIGEST_RAW" = "true" ]; then
        _health_set "digest_md5" "critical" "DIGEST-MD5 auth scheme is ENABLED (weak, legacy)" "Disabled" "Enabled" "Enabled"
    elif [ "$DIGEST_RAW" = "false" ]; then
        _health_set "digest_md5" "pass" "DIGEST-MD5 auth scheme is disabled" "Disabled" "Disabled" "Disabled"
    else
        _health_set "digest_md5" "critical" "Auth scheme list not available - cannot verify DIGEST-MD5 status" "Disabled" "" "N/A"
    fi

    # --- Two-factor authentication (bypass enabled = WARN) ---
    local TWOFA_RAW="${DATA[security.login.2fa_bypass_enabled]:-}"
    if [[ "$TWOFA_RAW" == "1" || "$TWOFA_RAW" == "true" || "$TWOFA_RAW" == "TRUE" || "$TWOFA_RAW" == "True" ]]; then
        _health_set "access.2fa" "warn" "2FA bypass is enabled" "2FA active" "bypass enabled" "Bypass enabled (2FA off)"
    else
        _health_set "access.2fa" "pass" "2FA is active (no bypass)" "2FA active" "2FA active" "2FA active"
    fi

    # --- Backup (using icewarp.* and backup.db.* keys) ---
    local AUTO_ENABLED="${DATA[icewarp.backup.auto_enabled]:-0}"
    local LAST_TIME="${DATA[icewarp.backup.last_time]:-}"
    local DB_ACCOUNTS="${DATA[backup.db.accounts.enabled]:-0}"
    local DB_AS="${DATA[backup.db.as.enabled]:-0}"
    local DB_GW="${DATA[backup.db.gw.enabled]:-0}"
    local DB_CACHE="${DATA[backup.db.cache.enabled]:-0}"

    _health_bool "backup.auto" "$AUTO_ENABLED" "critical" \
        "Automatic system backup is enabled" "Automatic system backup is DISABLED (required for production)" "Enabled" "Disabled"
    # Overall database backup: PASS if at least Accounts is enabled (core DB)
    _health_bool "backup.db" "$DB_ACCOUNTS" "critical" \
        "Database backup is enabled (Accounts)" "Database backup is DISABLED (Accounts missing)" "Enabled" "Disabled"
    _health_bool "backup.db.accounts" "$DB_ACCOUNTS" "critical" \
        "Accounts database backup is enabled" "Accounts database backup is DISABLED" "Enabled" "Disabled"
    _health_bool "backup.db.as" "$DB_AS" "critical" \
        "Anti-Spam database backup is enabled" "Anti-Spam database backup is DISABLED" "Enabled" "Disabled"
    _health_bool "backup.db.gw" "$DB_GW" "critical" \
        "GroupWare database backup is enabled" "GroupWare database backup is DISABLED" "Enabled" "Disabled"

    # Directory Cache backup is optional: either state is acceptable, so it is
    # always "pass" (registry flag opt). No INFO status (CLAUDE.md 3.3).
    if [ "$DB_CACHE" = "1" ]; then
        _health_set "backup.db.cache" "pass" "Directory Cache database backup is enabled (optional)" "optional" "Enabled" "Enabled"
    else
        _health_set "backup.db.cache" "pass" "Directory Cache database backup is disabled (optional)" "optional" "Disabled" "Disabled"
    fi

    # Last backup time: <2 days pass, <7 warn, else critical
    if [ -n "$LAST_TIME" ] && [ "$LAST_TIME" != "null" ] && [ "$LAST_TIME" != "N/A" ]; then
        local DAYS
        DAYS="$(_days_ago "$LAST_TIME")"
        if [ -z "$DAYS" ]; then
            _health_set "backup.last_time" "warn" "Last backup time could not be parsed: $LAST_TIME" "<2 days" "" "$LAST_TIME"
        elif [ "$DAYS" -lt 2 ]; then
            _health_set "backup.last_time" "pass" "Last backup run: $LAST_TIME ($DAYS days ago)" "<2 days" "$DAYS" "$LAST_TIME ($DAYS days ago)"
        elif [ "$DAYS" -lt 7 ]; then
            _health_set "backup.last_time" "warn" "Last backup run: $LAST_TIME ($DAYS days ago) - consider recent backup" "<2 days" "$DAYS" "$LAST_TIME ($DAYS days ago)"
        else
            _health_set "backup.last_time" "critical" "Last backup run: $LAST_TIME ($DAYS days ago) - too old" "<2 days" "$DAYS" "$LAST_TIME ($DAYS days ago)"
        fi
    else
        _health_set "backup.last_time" "warn" "No backup history found (manual run never executed)" "<2 days" "" "Never"
    fi

    # --- Watchdog (main enable + individual services) ---
    local INTERVAL="${DATA[watchdog.interval_minutes]:-0}"
    _health_bool "watchdog.control" "${DATA[watchdog.control]:-0}" "critical" \
        "System Watchdog is ENABLED" "System Watchdog is DISABLED" "Enabled" "Disabled"
    _health_bool "watchdog.smtp" "${DATA[watchdog.smtp]:-0}" "critical" \
        "SMTP Watchdog is ENABLED" "SMTP Watchdog is DISABLED" "Enabled" "Disabled"
    _health_bool "watchdog.pop3" "${DATA[watchdog.pop3]:-0}" "critical" \
        "POP3/IMAP Watchdog is ENABLED" "POP3/IMAP Watchdog is DISABLED" "Enabled" "Disabled"
    _health_bool "watchdog.im" "${DATA[watchdog.im]:-0}" "critical" \
        "IM/VoIP Watchdog is ENABLED" "IM/VoIP Watchdog is DISABLED" "Enabled" "Disabled"
    _health_bool "watchdog.gw" "${DATA[watchdog.gw]:-0}" "critical" \
        "GroupWare Watchdog is ENABLED" "GroupWare Watchdog is DISABLED" "Enabled" "Disabled"

    # Watchdog interval: 0..60 pass, <=1440 warn, else critical
    if ! _is_num "$INTERVAL"; then
        _health_set "watchdog.interval" "warn" "Interval is not a number: ${INTERVAL}" "<=60" "" "$INTERVAL"
    elif [ "$INTERVAL" -eq 0 ]; then
        _health_set "watchdog.interval" "pass" "Interval: Every minute (0) - optimal" "<=60" "0" "0"
    elif [ "$INTERVAL" -ge 1 ] && [ "$INTERVAL" -le 60 ]; then
        _health_set "watchdog.interval" "pass" "Interval: ${INTERVAL} minutes (optimal)" "<=60" "$INTERVAL" "$INTERVAL"
    elif [ "$INTERVAL" -gt 60 ] && [ "$INTERVAL" -le 1440 ]; then
        _health_set "watchdog.interval" "warn" "Interval: ${INTERVAL} minutes (more than 1 hour - consider reducing)" "<=60" "$INTERVAL" "$INTERVAL"
    else
        _health_set "watchdog.interval" "critical" "Interval: ${INTERVAL} minutes (too long or invalid)" "<=60" "$INTERVAL" "$INTERVAL"
    fi

    # --- System Monitor ---
    local MONITOR_ENABLED="${DATA[monitor.enabled]:-0}"
    if [ "$MONITOR_ENABLED" = "1" ]; then
        local CPU_TH="${DATA[monitor.cpu.threshold_percent]:-50}"
        local MEM_TH="${DATA[monitor.memory.alert_below_kb]:-1048576}"
        local DISK_TH="${DATA[monitor.disk.alert_below_mb]:-5120}"
        _health_set "monitor.enabled" "pass" "System Monitor ENABLED (CPU>${CPU_TH}% | RAM<${MEM_TH}KB | DISK<${DISK_TH}MB)" "Enabled" "Enabled" "Enabled"
    else
        _health_set "monitor.enabled" "critical" "System Monitor is DISABLED" "Enabled" "Disabled" "Disabled"
    fi

    # --- OS Last Update: <=7 days pass, <=30 warn, else critical ---
    local LAST_UPDATE="${DATA[os.last_update_date]:-}"
    if [ -n "$LAST_UPDATE" ] && [ "$LAST_UPDATE" != "N/A" ] && [ "$LAST_UPDATE" != "null" ]; then
        _health_age "os_update" "$LAST_UPDATE" "OS last update" 7 30 "critical"
    else
        _health_set "os_update" "skip" "OS last update date not available"
    fi

    # --- Directory Cache Schedule (empty schedule = not scheduled = CRITICAL) ---
    local CACHE_SCHED="${DATA[directory_cache.schedule_raw]:-}"
    if [ -z "$CACHE_SCHED" ] || [ "$CACHE_SCHED" = "not scheduled" ] || [ "$CACHE_SCHED" = "null" ]; then
        _health_set "directory_cache" "critical" "Directory Cache schedule is NOT SET" "scheduled" "not scheduled" "Not scheduled"
    else
        _health_set "directory_cache" "pass" "Directory Cache schedule is configured (${CACHE_SCHED})" "scheduled" "scheduled" "Scheduled"
    fi

    # --- Intrusion Prevention (Strict Override: 50/360 + the five count rules) ---
    _health_expect "intrusion.block_connections" "Block IP - Connections in 1 Minute"      "security.intrusion.block_connections_per_minute.value" "50"
    _health_expect "intrusion.unknown_user"      "Block IP - Unknown User Delivery Count"  "security.intrusion.block_unknown_user_count.value"       "5"
    _health_expect "intrusion.relay_denied"      "Block IP - Denied for Relaying Too Often" "security.intrusion.block_relay_denied_count.value"     "5"
    _health_expect "intrusion.rset"              "Block IP - Exceeds RSET Session Count"   "security.intrusion.block_rset_count.value"              "5"
    _health_expect "intrusion.spam_score"        "Block IP - Message Spam Score"           "security.intrusion.block_spam_score.value"             "9.00"
    _health_expect "intrusion.failed_logins"     "Block IP - Exceeds Failed Login Attempts" "security.intrusion.block_failed_logins.value"          "5"
    _health_expect "intrusion.block_duration"    "Amount of Time IP is Blocked (minutes)"  "security.intrusion.block_duration_minutes"             "360"

    # --- Admin Email (Strict Override: empty=CRITICAL, invalid=WARN) ---
    local ADMIN_EMAIL="${DATA[monitor.alert_email]:-}"
    if [ -z "$ADMIN_EMAIL" ] || [ "$ADMIN_EMAIL" = "null" ] || [ "$ADMIN_EMAIL" = "N/A" ]; then
        _health_set "admin_email" "critical" "Admin email is not set" "valid email address" "" "empty"
    elif [[ "$ADMIN_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        _health_set "admin_email" "pass" "Admin email is configured: ${ADMIN_EMAIL}" "valid email address" "$ADMIN_EMAIL" "$ADMIN_EMAIL"
    else
        _health_set "admin_email" "warn" "Admin email is set but invalid format: ${ADMIN_EMAIL}" "valid email address" "$ADMIN_EMAIL" "$ADMIN_EMAIL"
    fi

    # --- Session Timeout (Strict Override: has value=PASS, missing/empty/0=WARN) ---
    local SESSION_TIMEOUT="${DATA[icewarp.session_timeout_minutes]:-}"
    if [ -n "$SESSION_TIMEOUT" ] && [ "$SESSION_TIMEOUT" != "null" ] && [ "$SESSION_TIMEOUT" != "N/A" ] && [ "$SESSION_TIMEOUT" != "0" ]; then
        _health_set "session_timeout" "pass" "Session timeout is configured: ${SESSION_TIMEOUT} minutes" ">0 minutes" "$SESSION_TIMEOUT" "${SESSION_TIMEOUT} minutes"
    else
        _health_set "session_timeout" "warn" "Session timeout is not set or is 0" ">0 minutes" "" "not set"
    fi

    # --- IMAP / POP3 Services (Strict Override: Running=PASS, Disabled=WARN) ---
    local IMAP_ACTIVE="${DATA[service.imap.active]:-0}"
    local POP3_ACTIVE="${DATA[service.pop3.active]:-0}"
    _health_bool "service.imap" "$IMAP_ACTIVE" "warn" "IMAP service is running" "IMAP service is disabled" "Running" "Disabled"
    _health_bool "service.pop3" "$POP3_ACTIVE" "warn" "POP3 service is running" "POP3 service is disabled" "Running" "Disabled"

    # --- SMTP simultaneous threads (detail only, expected 10) ---
    _health_expect "smtp.threads" "Maximum Number of Simultaneous Threads" "smtp.incoming_queue_threads" "10"

    # --- Mail-flow DNS / STARTTLS checks ---
    # _mail_check <id> <label> <data key> <result when false>
    _mail_check() {
        local ID="$1" LABEL="$2" VAL="${DATA[$3]:-}" BAD="$4"
        if [ -z "$VAL" ]; then
            _health_set "$ID" "skip" "${LABEL} check did not return data"
        elif [ "$VAL" = "true" ] || [ "$VAL" = "1" ]; then
            _health_set "$ID" "pass" "${LABEL} is OK" "true" "true" "OK"
        else
            _health_set "$ID" "$BAD" "${LABEL} is missing or failed" "true" "false" "Failed"
        fi
    }
    _mail_check "mail.spf"        "SPF record"  "dns.spf.found"           "fail"
    _mail_check "mail.dkim"       "DKIM record" "dns.dkim.found"          "fail"
    _mail_check "mail.dmarc"      "DMARC record" "dns.dmarc.found"        "warn"
    _mail_check "mail.ptr"        "PTR record"  "dns.ptr.exists"          "warn"
    _mail_check "mail.starttls"   "STARTTLS"    "smtp.starttls_live_test" "fail"
    _mail_check "mail.dns_lookup" "DNS lookup"  "dns.lookup_test.ok"      "fail"
    unset -f _mail_check
    if [ "${HEALTH[mail.ptr]:-}" = "pass" ] && [ "${DATA[dns.ptr.matches_hostname]:-}" = "false" ]; then
        _health_set "mail.ptr" "warn" "PTR does not match the mail hostname" "matches hostname" "mismatch" "Mismatch"
    fi
    if [ "${HEALTH[mail.spf]:-}" = "pass" ] && [ "${DATA[dns.spf.includes_server_ip]:-}" = "false" ]; then
        _health_set "mail.spf" "warn" "SPF does not include this server's IP" "includes server IP" "missing" "IP not in SPF"
    fi

    # --- DNSBL Zones Check ---
    # The zone list is read from IceWarp config files (no tool.sh property).
    # "not_found" means the file could not be read - say so instead of claiming
    # that nothing is configured.
    local DNSBL_ZONES="${DATA[security.dnsbl.zones]:-}"
    local DNSBL_COUNT="${DATA[security.dnsbl.zones.count]:-0}"
    local DNSBL_SRC="${DATA[security.dnsbl.zones.source]:-not_found}"
    local DNSBL_EMPTY_MSG="No recommended DNSBL zones found in the IceWarp config (bl.spamcop.net, zen.spamhaus.org)"
    [ "$DNSBL_SRC" = "not_found" ] && DNSBL_EMPTY_MSG="DNSBL zone list could not be read from the IceWarp config (verify manually)"
    local DNSBL_EXP="bl.spamcop.net or zen.spamhaus.org"
    if [ -z "$DNSBL_ZONES" ] || ! _is_num "$DNSBL_COUNT" || [ "$DNSBL_COUNT" -eq 0 ]; then
        _health_set "dnsbl_zones" "warn" "$DNSBL_EMPTY_MSG" "$DNSBL_EXP" "" "none found"
    elif echo "$DNSBL_ZONES" | grep -qiE "bl\.spamcop\.net|zen\.spamhaus\.org"; then
        _health_set "dnsbl_zones" "pass" "DNSBL zones configured: $DNSBL_ZONES (includes recommended)" "$DNSBL_EXP" "$DNSBL_ZONES" "$DNSBL_ZONES"
    else
        _health_set "dnsbl_zones" "warn" "DNSBL zones configured: $DNSBL_ZONES (missing recommended: bl.spamcop.net, zen.spamhaus.org)" "$DNSBL_EXP" "$DNSBL_ZONES" "$DNSBL_ZONES"
    fi

    # --- Threat protection inputs: definition age (<=7 pass, <=30 warn, else fail) ---
    local TH_DATE
    TH_DATE="${DATA[icewarp.antispam.last_update]:-}"
    if [ -n "$TH_DATE" ] && [ "$TH_DATE" != "N/A" ] && [ "$TH_DATE" != "null" ]; then
        _health_age "threat.antispam" "$TH_DATE" "Antispam definitions" 7 30 "fail"
    else
        _health_set "threat.antispam" "warn" "Antispam update date unavailable" "<=7 days" "" "N/A"
    fi
    TH_DATE="${DATA[icewarp.antivirus.last_update]:-}"
    if [ -n "$TH_DATE" ] && [ "$TH_DATE" != "N/A" ] && [ "$TH_DATE" != "null" ]; then
        _health_age "threat.antivirus" "$TH_DATE" "Antivirus definitions" 7 30 "fail"
    else
        _health_set "threat.antivirus" "warn" "Antivirus update date unavailable" "<=7 days" "" "N/A"
    fi
    if [ "${DATA[security.rbl_self_check.checked]:-}" = "true" ]; then
        if [ "${DATA[security.rbl_self_check.listed]:-}" = "true" ]; then
            _health_set "threat.rbl" "fail" "Server IP is listed on ${DATA[security.rbl_self_check.listed_on]:-an RBL}" "not listed" "listed" "Listed"
        else
            _health_set "threat.rbl" "pass" "Server IP is not listed on the checked RBLs" "not listed" "not listed" "Not listed"
        fi
    else
        _health_set "threat.rbl" "skip" "RBL self-check did not run"
    fi
    case "${DATA[security.cyren_folder.status]:-}" in
        WARN) _health_set "threat.cyren" "warn" "${DATA[security.cyren_folder.message]:-Old AntiSpam folders need cleanup}" "OK" "WARN" "WARN" ;;
        OK)   _health_set "threat.cyren" "pass" "${DATA[security.cyren_folder.message]:-No old AntiSpam folders}" "OK" "OK" "OK" ;;
        *)    _health_set "threat.cyren" "skip" "Old AntiSpam folder check did not return a status" ;;
    esac

    # --- Database platform (Strict Override: SQLite=WARN, MySQL=PASS, no INFO/unknown) ---
    local DB_TYPE="${DATA[database.type]:-}"
    case "$DB_TYPE" in
        sqlite) _health_set "database.platform" "warn" "SQLite is in use; MySQL is recommended for production" "mysql" "sqlite" "sqlite" ;;
        mysql)  _health_set "database.platform" "pass" "MySQL database platform is active" "mysql" "mysql" "mysql" ;;
        unknown|"") _health_set "database.platform" "warn" "Database type could not be determined (unknown/empty)" "mysql" "unknown" "unknown" ;;
        *)      _health_set "database.platform" "warn" "Unrecognised database type: ${DB_TYPE}" "mysql" "$DB_TYPE" "$DB_TYPE" ;;
    esac

    # --- Pillar roll-ups (derived from the registry) ---
    local P
    for P in "${HEALTH_PILLARS[@]}"; do
        [ "$P" = "os_update" ] && continue   # the os_update check IS the pillar
        _pillar_rollup "$P"
    done

    # --- Summary (nine executive pillars) ---
    local TOTAL=0 FAIL=0 WARN=0 K RES
    for K in "${HEALTH_PILLARS[@]}"; do
        RES="${HEALTH[$K]:-skip}"
        [ "$RES" = "skip" ] && continue
        TOTAL=$((TOTAL+1))
        if [ "$RES" = "fail" ] || [ "$RES" = "critical" ]; then FAIL=$((FAIL+1)); fi
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
