#!/bin/bash

###############################################################################
#
# health.v2.json builder  (schema: docs/schema/health.v2.schema.json)
#
# Envelope for monitoring/mobile consumers: summary + 9 pillars + checks[] +
# typed metrics + the unchanged flat keys under "raw". health.json (v1) is not
# modified. Read-only over DATA[] / HEALTH[] / HEALTH_MSG[] / STATUS[].
#
# Status vocabulary: ok | warn | crit | unknown
#   pass->ok  info->ok  warn->warn  fail|critical->crit  skip->unknown
#
###############################################################################

_V2_PILLARS=(backup mail_flow tls access threat resources os_update monitoring database)

# check id -> "pillar|title|flags"   flags: ru = rolled up into its pillar by
# health.sh, opt = optional feature (never makes a pillar worse)
declare -Ag _V2_META=(
    [backup.auto]="backup|Automatic system backup|ru"
    [backup.db]="backup|Database backup|ru"
    [backup.db.accounts]="backup|Accounts database backup|"
    [backup.db.as]="backup|Anti-Spam database backup|"
    [backup.db.gw]="backup|GroupWare database backup|"
    [backup.db.cache]="backup|Directory Cache database backup|opt"
    [backup.last_time]="backup|Last backup run|ru"
    [tls_delivery]="tls|TLS/SSL for delivery|ru"
    [login_blocking]="access|Login blocking|ru"
    [password_policy]="access|Password policy|ru"
    [digest_md5]="access|DIGEST-MD5 disabled|ru"
    [admin_email]="access|Admin email|ru"
    [session_timeout]="access|Session timeout|ru"
    [service.imap]="mail_flow|IMAP service|"
    [service.pop3]="mail_flow|POP3 service|"
    [dnsbl_zones]="mail_flow|DNSBL zones|ru"
    [intrusion.block_connections]="threat|Intrusion: connections per minute|"
    [intrusion.block_duration]="threat|Intrusion: block duration|"
    [memory]="resources|Memory|ru"
    [cpu]="resources|CPU|ru"
    [disk.overall]="resources|Disk space|ru"
    [monitor.enabled]="monitoring|System Monitor|ru"
    [watchdog.control]="monitoring|Watchdog|ru"
    [watchdog.smtp]="monitoring|SMTP watchdog|"
    [watchdog.pop3]="monitoring|POP3/IMAP watchdog|"
    [watchdog.im]="monitoring|IM/VoIP watchdog|"
    [watchdog.gw]="monitoring|GroupWare watchdog|"
    [watchdog.interval]="monitoring|Watchdog interval|ru"
    [directory_cache]="database|Directory Cache schedule|"
)

_v2_status() {
    case "$1" in
        pass|info|ok) printf 'ok' ;;
        warn)         printf 'warn' ;;
        fail|critical|crit) printf 'crit' ;;
        *)            printf 'unknown' ;;
    esac
}

_v2_str()  { local V="${1:-}"; if [ -z "$V" ] || [ "$V" = "null" ]; then printf 'null'; else printf '"%s"' "$(_json_escape "$V")"; fi; }
_v2_num()  { if _json_is_number "${1:-}"; then printf '%s' "$1"; else printf 'null'; fi; }
_v2_bool() { case "${1:-}" in 1|true) printf 'true' ;; 0|false) printf 'false' ;; *) printf 'null' ;; esac; }
_v2_date() { local D; D="$(norm_date "${1:-}")" && printf '"%s"' "$D" || printf 'null'; }

# loosely typed expected/actual (number, bool or string)
_v2_scalar() {
    local V="${1:-}"
    if [ -z "$V" ]; then printf 'null'
    elif _json_is_number "$V" || _json_is_bool "$V"; then printf '%s' "$V"
    else printf '"%s"' "$(_json_escape "$V")"; fi
}

_v2_datetime() {
    # "2026-10-31 05:30:55" -> ISO-8601 with offset, or null
    local V="${1:-}" T
    [[ "$V" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[\ T][0-9]{2}:[0-9]{2} ]] || { printf 'null'; return; }
    T="$(date -d "$V" -Iseconds 2>/dev/null)" && printf '"%s"' "$T" || printf 'null'
}

_v2_uuid() {
    cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || \
        printf '%08x-%04x-4%03x-8%03x-%012x\n' $RANDOM$RANDOM $RANDOM $((RANDOM%4096)) $((RANDOM%4096)) $RANDOM$RANDOM$RANDOM
}

# Persistent per-server id, created on first run. Lives next to the agent
# (gitignored) so auto-update never sees a dirty tree.
_v2_server_id() {
    local FILE="${SERVER_ID_FILE:-${PROJECT_ROOT}/.server_id}" ID=""
    [ -f "$FILE" ] && ID="$(tr -d '[:space:]' < "$FILE" 2>/dev/null)"
    if ! [[ "$ID" =~ ^[0-9a-fA-F-]{36}$ ]]; then
        ID="$(_v2_uuid | tr -d '[:space:]')"
        printf '%s\n' "$ID" > "$FILE" 2>/dev/null || true
    fi
    printf '%s' "$ID"
}

_v2_pct() {
    # _v2_pct <numerator> <denominator> [multiplier]  -> number with 1 decimal or null
    if _json_is_number "${1:-}" && _json_is_number "${2:-}"; then
        awk -v n="$1" -v d="$2" -v m="${3:-100}" 'BEGIN{ if (d>0) printf "%.1f", n/d*m; else printf "null" }'
    else printf 'null'; fi
}

_v2_checks() {
    local K META PILLAR TITLE FLAGS RES ST EXP ACT FIRST=1 RU OPT ID
    local -a IDS=()
    for K in "${!HEALTH[@]}"; do
        [[ "${HEALTH[$K]}" == same_as:* ]] && continue
        [ -n "${_V2_META[$K]:-}" ] && IDS+=("$K")
        # per-mount disks: disk.<name> (not overall)
        [[ "$K" == disk.* && "$K" != "disk.overall" && -z "${_V2_META[$K]:-}" ]] && IDS+=("$K")
    done
    printf '['
    for ID in $(printf '%s\n' "${IDS[@]}" | sort); do
        META="${_V2_META[$ID]:-resources|Disk ${ID#disk.}|}"
        IFS='|' read -r PILLAR TITLE FLAGS <<< "$META"
        RES="${HEALTH[$ID]}"; ST="$(_v2_status "$RES")"
        RU=false; OPT=false
        [[ "$FLAGS" == *ru* ]] && RU=true
        [[ "$FLAGS" == *opt* || "$RES" == "info" ]] && OPT=true
        [ $FIRST -eq 0 ] && printf ','
        FIRST=0
        printf '\n    {"id":"%s","pillar":"%s","status":"%s","optional":%s,"rolled_up":%s,"title":"%s","message":"%s","expected":%s,"actual":%s}' \
            "$ID" "$PILLAR" "$ST" "$OPT" "$RU" "$(_json_escape "$TITLE")" "$(_json_escape "${HEALTH_MSG[$ID]:-}")" \
            "$(_v2_scalar "${HEALTH_EXPECTED[$ID]:-}")" "$(_v2_scalar "${HEALTH_ACTUAL[$ID]:-}")"
    done
    printf '\n  ]'
}

_v2_disks() {
    local N KEY DEV MNT ROLE FIRST=1 IDX
    local -A SEEN_ROLES=() SEEN_NAME=()
    local -a ORDER=()
    # fixed order so the physical disk is named after its most general role
    for N in root_fs root_home install mail archive; do
        KEY="storage.$N.mount"
        [ -n "${DATA[$KEY]:-}" ] || continue
        DEV="${DATA[storage.$N.device]:-}"; MNT="${DATA[$KEY]}"
        IDX="${DEV}|${MNT}"
        case "$N" in root_fs) ROLE=root ;; root_home) ROLE=home ;; *) ROLE="$N" ;; esac
        if [ -z "${SEEN_NAME[$IDX]:-}" ]; then SEEN_NAME[$IDX]="$N"; SEEN_ROLES[$IDX]="$ROLE"; ORDER+=("$IDX")
        else SEEN_ROLES[$IDX]="${SEEN_ROLES[$IDX]},$ROLE"; fi
    done
    printf '['
    for IDX in "${ORDER[@]}"; do
        N="${SEEN_NAME[$IDX]}"
        [ $FIRST -eq 0 ] && printf ','
        FIRST=0
        printf '\n      {"name":"%s","mount":"%s","total_gb":%s,"free_gb":%s,"used_percent":%s,"roles":[%s]}' \
            "$N" "$(_json_escape "${DATA[storage.$N.mount]:-}")" \
            "$(_v2_num "${DATA[storage.$N.total_gb]:-}")" "$(_v2_num "${DATA[storage.$N.free_gb]:-}")" \
            "$(_v2_num "${DATA[storage.$N.used_percent]:-}")" \
            "$(printf '%s' "${SEEN_ROLES[$IDX]}" | sed 's/[^,]*/"&"/g')"
    done
    printf '\n    ]'
}

build_json_v2() {

    local OUT="${OUTPUT_JSON_V2:-${OUTPUT_DIR:-${PROJECT_ROOT}/output}/health.v2.json}"
    local TMP="${OUT}.tmp.$$"
    local NOW_ISO START_ISO START_MS NOW_MS P ST FIRST COUNT_OK=0 COUNT_WARN=0 COUNT_CRIT=0 COUNT_UNK=0 SCORE_SUM=0 SCORE_N=0 SCORE
    local C_TOTAL=0 C_OK=0 C_FAIL=0 CN KEY EXP_ISO DOMAINS D OVERALL

    NOW_MS="$(date +%s%3N)"; NOW_ISO="$(date -Iseconds)"
    START_MS="${AGENT_RUN_START_MS:-$NOW_MS}"
    START_ISO="$(date -d "@$((START_MS/1000))" -Iseconds 2>/dev/null || echo "$NOW_ISO")"

    # ---- pillar roll-up counts + score (ok=100, warn=50, crit=0; unknown excluded) ----
    for P in "${_V2_PILLARS[@]}"; do
        ST="$(_v2_status "${HEALTH[$P]:-skip}")"
        case "$ST" in
            ok)   COUNT_OK=$((COUNT_OK+1));     SCORE_SUM=$((SCORE_SUM+100)); SCORE_N=$((SCORE_N+1)) ;;
            warn) COUNT_WARN=$((COUNT_WARN+1)); SCORE_SUM=$((SCORE_SUM+50));  SCORE_N=$((SCORE_N+1)) ;;
            crit) COUNT_CRIT=$((COUNT_CRIT+1)); SCORE_N=$((SCORE_N+1)) ;;
            *)    COUNT_UNK=$((COUNT_UNK+1)) ;;
        esac
    done
    if [ "$SCORE_N" -gt 0 ]; then SCORE=$(( (SCORE_SUM + SCORE_N/2) / SCORE_N )); else SCORE=null; fi
    OVERALL="$(_v2_status "${DATA[health.summary.overall]:-skip}")"

    # ---- collector run stats ----
    local -a FAILED=()
    for CN in "${!STATUS[@]}"; do
        C_TOTAL=$((C_TOTAL+1))
        if [ "${STATUS[$CN]}" = "ok" ]; then C_OK=$((C_OK+1)); else C_FAIL=$((C_FAIL+1)); FAILED+=("$CN"); fi
    done

    DOMAINS=""
    IFS=';' read -ra _DOMS <<< "${DATA[domain.list]:-}"
    for D in "${_DOMS[@]}"; do [ -n "$D" ] && DOMAINS="${DOMAINS:+$DOMAINS,}\"$(_json_escape "$D")\""; done

    EXP_ISO="$(date -d "${DATA[icewarp.ssl.expiration]:-}" +%F 2>/dev/null)" || EXP_ISO=""

    {
    printf '{\n'
    printf '  "schema_version":"2.0",\n'
    printf '  "generated_at":"%s",\n' "$NOW_ISO"
    printf '  "agent":{"version":%s,"platform":"linux","checklist_version":%s},\n' \
        "$(_v2_str "${AGENT_VERSION:-}")" "$(_v2_str "${CHECKLIST_VERSION:-}")"
    printf '  "server":{"id":"%s","hostname":%s,"company":%s,"technician":%s,"primary_domain":%s,"domains":[%s],"os":{"name":%s,"version":%s},"icewarp_version":%s},\n' \
        "$(_v2_server_id)" "$(_v2_str "${DATA[agent.hostname]:-unknown}")" "$(_v2_str "${DATA[general.company]:-}")" \
        "$(_v2_str "${DATA[general.technician]:-}")" "$(_v2_str "${DATA[domain.primary.name]:-}")" "$DOMAINS" \
        "$(_v2_str "${DATA[general.os.name]:-}")" "$(_v2_str "${DATA[general.os.version]:-}")" "$(_v2_str "${DATA[general.icewarp.version]:-}")"
    printf '  "run":{"id":"%s","started_at":"%s","finished_at":"%s","duration_ms":%s,"collectors":{"total":%s,"ok":%s,"failed":%s,"failed_list":[%s]}},\n' \
        "$(_v2_uuid | tr -d '[:space:]')" "$START_ISO" "$NOW_ISO" "$((NOW_MS-START_MS))" "$C_TOTAL" "$C_OK" "$C_FAIL" \
        "$(for CN in "${FAILED[@]}"; do printf '"%s"\n' "$(_json_escape "$CN")"; done | paste -sd',' -)"

    printf '  "summary":{"overall":"%s","score":%s,"counts":{"ok":%s,"warn":%s,"crit":%s,"unknown":%s},"pillars":[' \
        "$OVERALL" "$SCORE" "$COUNT_OK" "$COUNT_WARN" "$COUNT_CRIT" "$COUNT_UNK"
    FIRST=1
    for P in "${_V2_PILLARS[@]}"; do
        [ $FIRST -eq 0 ] && printf ','
        FIRST=0
        printf '\n    {"id":"%s","status":"%s","message":"%s"}' "$P" "$(_v2_status "${HEALTH[$P]:-skip}")" "$(_json_escape "${HEALTH_MSG[$P]:-}")"
    done
    printf '\n  ]},\n'

    printf '  "checks":'; _v2_checks; printf ',\n'

    printf '  "metrics":{\n'
    printf '    "cpu":{"cores":%s,"usage_percent":%s,"load1":%s,"load5":%s,"load15":%s},\n' \
        "$(_v2_num "${DATA[os.cpu.count]:-}")" "$(_v2_pct "${DATA[os.cpu.load1]:-}" "${DATA[os.cpu.count]:-}")" \
        "$(_v2_num "${DATA[os.cpu.load1]:-}")" "$(_v2_num "${DATA[os.cpu.load5]:-}")" "$(_v2_num "${DATA[os.cpu.load15]:-}")"
    printf '    "memory":{"total_kb":%s,"available_kb":%s,"used_percent":%s},\n' \
        "$(_v2_num "${DATA[os.memory.total_kb]:-}")" "$(_v2_num "${DATA[os.memory.available_kb]:-}")" \
        "$( _json_is_number "${DATA[os.memory.total_kb]:-}" && _json_is_number "${DATA[os.memory.available_kb]:-}" \
            && _v2_pct "$(( ${DATA[os.memory.total_kb]} - ${DATA[os.memory.available_kb]} ))" "${DATA[os.memory.total_kb]}" || printf 'null')"
    printf '    "swap":{"total_kb":%s,"used_percent":%s},\n' \
        "$(_v2_num "${DATA[os.swap.total_kb]:-}")" \
        "$( _json_is_number "${DATA[os.swap.total_kb]:-}" && _json_is_number "${DATA[os.swap.free_kb]:-}" \
            && _v2_pct "$(( ${DATA[os.swap.total_kb]} - ${DATA[os.swap.free_kb]} ))" "${DATA[os.swap.total_kb]}" || printf 'null')"
    printf '    "disks":'; _v2_disks; printf ',\n'
    printf '    "certificate":{"expires_at":%s,"days_left":%s},\n' \
        "$([ -n "$EXP_ISO" ] && printf '"%s"' "$EXP_ISO" || printf 'null')" "$(_v2_num "${DATA[icewarp.ssl.days_left]:-}")"
    printf '    "backup":{"last_run_at":%s,"auto_enabled":%s},\n' \
        "$(_v2_datetime "${DATA[icewarp.backup.last_time]:-}")" "$(_v2_bool "${DATA[icewarp.backup.auto_enabled]:-}")"
    printf '    "definitions":{"antispam_updated_at":%s,"antivirus_updated_at":%s},\n' \
        "$(_v2_date "${DATA[icewarp.antispam.last_update]:-}")" "$(_v2_date "${DATA[icewarp.antivirus.last_update]:-}")"
    printf '    "os_updated_at":%s,\n' "$(_v2_date "${DATA[os.last_update_date]:-}")"
    printf '    "license":{"type":%s,"expires_at":%s,"max_users":%s,"used_users":null},\n' \
        "$(_v2_str "${DATA[icewarp.license.type]:-}")" "$(_v2_date "${DATA[icewarp.license.trial_expiration]:-}")" \
        "$(_v2_num "${DATA[icewarp.license.max_users_raw]:-}")"
    case "${DATA[database.type]:-}" in
        mysql|sqlite|unknown) printf '    "database":{"type":"%s"}\n' "${DATA[database.type]}" ;;
        *)                    printf '    "database":{"type":null}\n' ;;
    esac
    printf '  },\n'

    printf '  "raw":{'
    FIRST=1
    for KEY in $(printf '%s\n' "${!DATA[@]}" | sort); do
        [ $FIRST -eq 0 ] && printf ','
        FIRST=0
        printf '\n    "%s":%s' "$(_json_escape "$KEY")" "$(_json_value "$KEY" "${DATA[$KEY]}")"
    done
    printf '\n  }\n}\n'
    } > "$TMP" && mv -f "$TMP" "$OUT"

}
