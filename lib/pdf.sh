#!/bin/bash

###############################################################################
#
# PDF Report Writer (M5) - Reads checklist from config/checklist.conf.pdf
#
# All logic is applied dynamically based on KEYS and LABEL.
#
###############################################################################

PDF_PAGE_W=612
PDF_PAGE_H=792
PDF_MARGIN=36
PDF_TOP_Y=756
PDF_BOTTOM_Y=44
PDF_CONTENT_RIGHT=$((PDF_PAGE_W - PDF_MARGIN))
PDF_CONTENT_W=$((PDF_CONTENT_RIGHT - PDF_MARGIN))

# Colors
PDF_C_NAVY="0.102 0.235 0.369"
PDF_C_WHITE="1 1 1"
PDF_C_TEXT="0.15 0.17 0.2"
PDF_C_GRAY_LIGHT="0.955 0.96 0.965"
PDF_C_GREEN="0.118 0.518 0.286"
PDF_C_RED="0.753 0.224 0.169"
PDF_C_AMBER="0.83 0.53 0.06"
PDF_C_BLUEGRAY="0.30 0.42 0.55"
PDF_C_GRAY="0.5 0.53 0.56"

_pdf_escape() { local S="$1"; S="$(printf '%s' "$S" | LC_ALL=C tr -c '\40-\176' '?')"; S="${S//\\/\\\\}"; S="${S//(/\\(}"; S="${S//)/\\)}"; printf '%s' "$S"; }

_pdf_rect() {
    _PDF_CUR="${_PDF_CUR}${5} rg"$'\n'
    _PDF_CUR="${_PDF_CUR}${1} ${2} ${3} ${4} re f"$'\n'
}

_pdf_text() {
    local ESC="$(_pdf_escape "$3")"
    _PDF_CUR="${_PDF_CUR}${6} rg"$'\n'
    _PDF_CUR="${_PDF_CUR}BT /${4} ${5} Tf ${1} ${2} Td (${ESC}) Tj ET"$'\n'
}

_pdf_text_trunc() {
    local MAXCHARS="$7"
    local TXT="$3"
    [ "${#TXT}" -gt "$MAXCHARS" ] && TXT="${TXT:0:$((MAXCHARS-1))}."
    _pdf_text "$1" "$2" "$TXT" "$4" "$5" "$6"
}

_PDF_PAGES=(); _PDF_CUR=""; _PDF_Y=$PDF_TOP_Y

_layout_new_page() { [ -n "$_PDF_CUR" ] && _PDF_PAGES+=("$_PDF_CUR"); _PDF_CUR=""; _PDF_Y=$PDF_TOP_Y; }
_layout_ensure() { local NEEDED="$1"; [ "$((_PDF_Y - NEEDED))" -lt "$PDF_BOTTOM_Y" ] && _layout_new_page; }
_layout_finish() { [ -n "$_PDF_CUR" ] && _PDF_PAGES+=("$_PDF_CUR"); }

_layout_section_header() {
    local TITLE="$1"
    _layout_ensure 46
    _PDF_Y=$((_PDF_Y - 6))
    _pdf_rect "$PDF_MARGIN" "$((_PDF_Y - 18))" "$PDF_CONTENT_W" 22 "$PDF_C_NAVY"
    _pdf_text "$((PDF_MARGIN + 8))" "$((_PDF_Y - 12))" "$TITLE" "F2" 11 "$PDF_C_WHITE"
    _PDF_Y=$((_PDF_Y - 30))
}

_badge_color() {
    case "$1" in
        PASS)      echo "$PDF_C_GREEN" ;;
        CRITICAL)  echo "$PDF_C_RED" ;;
        WARN)      echo "$PDF_C_AMBER" ;;
        INFO)      echo "$PDF_C_BLUEGRAY" ;;
        *)         echo "$PDF_C_GRAY" ;;
    esac
}

_layout_row_index=0

_layout_row() {
    local LABEL="$1" VALUE="$2" BKIND="$3" BTEXT="$4" NOTE="${5:-}"
    local ROW_H=16; [ -n "$NOTE" ] && ROW_H=27
    _layout_ensure "$ROW_H"
    local BG="$PDF_C_WHITE"; [ $(( _layout_row_index % 2 )) -eq 1 ] && BG="$PDF_C_GRAY_LIGHT"
    _layout_row_index=$((_layout_row_index + 1))
    local ROW_TOP=$_PDF_Y
    _pdf_rect "$PDF_MARGIN" "$((ROW_TOP - ROW_H + 4))" "$PDF_CONTENT_W" "$ROW_H" "$BG"
    local TEXT_Y=$((ROW_TOP - 11))
    _pdf_text_trunc "$((PDF_MARGIN + 8))" "$TEXT_Y" "$LABEL" "F1" 9 "$PDF_C_TEXT" 46
    _pdf_text_trunc "$((PDF_MARGIN + 240))" "$TEXT_Y" "$VALUE" "F1" 9 "$PDF_C_GRAY" 34
    local BADGE_W=76 BADGE_H=13
    local BADGE_X=$((PDF_CONTENT_RIGHT - BADGE_W - 4))
    local BADGE_Y=$((ROW_TOP - 12))
    local BCOLOR="$(_badge_color "$BKIND")"
    _pdf_rect "$BADGE_X" "$BADGE_Y" "$BADGE_W" "$BADGE_H" "$BCOLOR"
    _pdf_text_trunc "$((BADGE_X + 6))" "$((BADGE_Y + 4))" "$BTEXT" "F2" 7.5 "$PDF_C_WHITE" 14
    [ -n "$NOTE" ] && _pdf_text_trunc "$((PDF_MARGIN + 8))" "$((TEXT_Y - 11))" "note: ${NOTE}" "F3" 7.5 "$PDF_C_GRAY" 100
    _PDF_Y=$((_PDF_Y - ROW_H))
}

_layout_plain_line() { _layout_ensure 12; _pdf_text_trunc "$PDF_MARGIN" "$_PDF_Y" "$1" "F1" 8.5 "$PDF_C_TEXT" 110; _PDF_Y=$((_PDF_Y - 12)); }

_layout_cover() {
    local HOST="${DATA[agent.hostname]:-unknown}" GEN="${DATA[agent.time]:-unknown}" VER="${DATA[agent.version]:-unknown}"
    local OVERALL="${DATA[health.summary.overall]:-n/a}" FAILED="${DATA[health.summary.failed]:-0}" WARNINGS="${DATA[health.summary.warnings]:-0}" CHECKED="${DATA[health.summary.total_checks]:-0}"
    _pdf_rect 0 692 "$PDF_PAGE_W" 100 "$PDF_C_NAVY"
    _pdf_text "$PDF_MARGIN" 754 "IceWarp Health Check Report" "F2" 22 "$PDF_C_WHITE"
    _pdf_text "$PDF_MARGIN" 730 "Based on IceWarp CheckList v1.12" "F3" 12 "$PDF_C_WHITE"
    _pdf_text "$PDF_MARGIN" 706 "Host: ${HOST}   Generated: ${GEN}   Agent v${VER}" "F1" 9.5 "$PDF_C_WHITE"
    _PDF_Y=660
    local INFO_ROWS=(
        "Company Name|${DATA[general.company]:-Unknown Host}"
        "Technician|${DATA[general.technician]:-Not Specified}"
        "IceWarp Version|${DATA[icewarp.version]:-unknown}"
        "Antispam Last Update|${DATA[icewarp.antispam.last_update]:-unknown}"
        "Antivirus Last Update|${DATA[icewarp.antivirus.last_update]:-unknown}"
        "Last Backup Date/Time|${DATA[icewarp.backup.last_time]:-unknown}"
        "License Expiration|${DATA[icewarp.license.trial_expiration]:-N/A (perpetual license)}"
        "SSL Expiration|${DATA[icewarp.ssl.expiration]:-not returned}"
    )
    for ROW in "${INFO_ROWS[@]}"; do
        local LBL="${ROW%%|*}"; local VAL="${ROW#*|}"
        _pdf_text "$((PDF_MARGIN + 8))" "$_PDF_Y" "${LBL}:" "F2" 9.5 "$PDF_C_TEXT"
        _pdf_text_trunc "$((PDF_MARGIN + 190))" "$_PDF_Y" "$VAL" "F1" 9.5 "$PDF_C_GRAY" 55
        _PDF_Y=$((_PDF_Y - 16))
    done
    _PDF_Y=$((_PDF_Y - 14))
    local BANNER_COLOR; case "$OVERALL" in pass) BANNER_COLOR="$PDF_C_GREEN" ;; warn) BANNER_COLOR="$PDF_C_AMBER" ;; fail) BANNER_COLOR="$PDF_C_RED" ;; *) BANNER_COLOR="$PDF_C_GRAY" ;; esac
    _pdf_rect "$PDF_MARGIN" "$((_PDF_Y - 44))" "$PDF_CONTENT_W" 44 "$BANNER_COLOR"
    _pdf_text "$((PDF_MARGIN + 14))" "$((_PDF_Y - 20))" "OVERALL: $(echo "$OVERALL" | tr '[:lower:]' '[:upper:]')" "F2" 15 "$PDF_C_WHITE"
    _pdf_text "$((PDF_MARGIN + 14))" "$((_PDF_Y - 36))" "${CHECKED} checks run  -  ${FAILED} failed  -  ${WARNINGS} warnings" "F1" 9.5 "$PDF_C_WHITE"
    _PDF_Y=$((_PDF_Y - 60))
    _pdf_text "$PDF_MARGIN" "$_PDF_Y" "Legend:" "F2" 8.5 "$PDF_C_TEXT"
    local LX=$((PDF_MARGIN + 46))
    local LEGEND_ITEMS=("PASS:Green" "CRITICAL:Red" "WARN:Orange" "INFO:Purple")
    for ITEM in "${LEGEND_ITEMS[@]}"; do
        local STATUS="${ITEM%%:*}"
        local BC
        case "$STATUS" in
            PASS) BC="$PDF_C_GREEN" ;;
            CRITICAL) BC="$PDF_C_RED" ;;
            WARN) BC="$PDF_C_AMBER" ;;
            INFO) BC="$PDF_C_BLUEGRAY" ;;
        esac
        _pdf_rect "$LX" "$((_PDF_Y - 3))" 26 11 "$BC"
        _pdf_text "$((LX + 30))" "$_PDF_Y" "$STATUS" "F1" 8 "$PDF_C_TEXT"
        LX=$((LX + 30 + 6*${#STATUS} + 14))
    done
    _PDF_Y=$((_PDF_Y - 20))
}

# Helper: days ago
_days_ago() {
    local date_str="$1"
    [[ -z "$date_str" ]] && echo "999"
    local date_epoch=$(date -d "$date_str" +%s 2>/dev/null)
    [[ -z "$date_epoch" ]] && echo "999"
    echo $(( ( $(date +%s) - date_epoch ) / 86400 ))
}

# Helper: watchdog status for OS items
_get_watchdog_status() {
    local KEYS="$1"
    local WATCHDOG_KEY=""
    case "$KEYS" in
        *storage.root_fs.used_percent*) WATCHDOG_KEY="watchdog.disk" ;;
        *os.cpu.load1*) WATCHDOG_KEY="watchdog.cpu" ;;
        *os.memory.total_kb*) WATCHDOG_KEY="watchdog.memory" ;;
        *os.last_update_date*) WATCHDOG_KEY="watchdog.os_update" ;;
    esac
    if [ -n "$WATCHDOG_KEY" ] && [ -n "${DATA[${WATCHDOG_KEY}.status]:-}" ]; then
        local STATUS="${DATA[${WATCHDOG_KEY}.status]}"
        local MSG="${DATA[${WATCHDOG_KEY}.message]:-}"
        local BKIND="INFO"
        case "$STATUS" in
            PASS) BKIND="PASS" ;;
            WARN) BKIND="WARN" ;;
            FAIL) BKIND="CRITICAL" ;;
            *) BKIND="INFO" ;;
        esac
        printf '%s|%s|%s' "$BKIND" "$STATUS" "$MSG"
    else
        printf 'INFO|INFO|'
    fi
}

# Helper: render value from keys
_cl_value_render() {
    local KEYS="$1"
    if [[ "$KEYS" == *,* ]]; then
        local -a PARTS=(); local K SHORT
        IFS=',' read -ra _KARR <<< "$KEYS"
        for K in "${_KARR[@]}"; do SHORT="${K##*.}"; PARTS+=("${SHORT}=${DATA[$K]:-?}"); done
        local JOINED="$(IFS=', '; echo "${PARTS[*]}")"; printf '%s' "$JOINED"
    else
        printf '%s' "${DATA[$KEYS]:-(empty)}"
    fi
}

_render_note_template() {
    local TEMPLATE="$1"; local RESULT="$TEMPLATE"
    while [[ "$RESULT" =~ \$\{([a-zA-Z0-9_.]+)\} ]]; do
        local REF="${BASH_REMATCH[1]}"; local VAL="${DATA[$REF]:-?}"
        RESULT="${RESULT//\$\{${REF}\}/${VAL}}"
    done
    printf '%s' "$RESULT"
}

_health_worst_of() {
    local KEYS="$1"; local WORST="pass"; local -a MSGS=()
    IFS=',' read -ra _HKARR <<< "$KEYS"
    for K in "${_HKARR[@]}"; do
        local RESULT="${HEALTH[$K]:-skip}"
        [ -n "${HEALTH_MSG[$K]:-}" ] && MSGS+=("${HEALTH_MSG[$K]}")
        case "$RESULT" in
            fail) WORST="fail" ;;
            warn) [ "$WORST" != "fail" ] && WORST="warn" ;;
        esac
    done
    local JOINED_MSG="$(IFS='; '; echo "${MSGS[*]}")"
    local BKIND="INFO"
    case "$WORST" in
        pass) BKIND="PASS" ;;
        warn) BKIND="WARN" ;;
        fail) BKIND="CRITICAL" ;;
    esac
    printf '%s|%s' "$BKIND" "$JOINED_MSG"
}

# ---------- Render checklist from file ----------
_render_checklist() {
    local CHECKLIST_FILE="${PROJECT_ROOT}/config/checklist.conf.pdf"
    local CUR_SECTION=""

    if [ ! -f "$CHECKLIST_FILE" ]; then
        _layout_plain_line "Checklist file not found: $CHECKLIST_FILE"
        return
    fi

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        line=$(echo "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$line" ] && continue

        IFS='~' read -r SECTION LABEL KIND KEYS NOTE <<< "$line"

        if [ "$SECTION" != "$CUR_SECTION" ]; then
            _layout_section_header "$SECTION"
            CUR_SECTION="$SECTION"
            _layout_row_index=0
        fi

        # ----- Special cases based on LABEL or KEYS -----
        # 1. MySQL Server section - auto N/A if not remote
        if [[ "$SECTION" == "MySQL Server"* ]] && [ "${DATA[database.scope]:-}" != "remote" ]; then
            local NA_REASON="not applicable"
            case "${DATA[database.type]:-}" in
                sqlite) NA_REASON="not applicable - this install uses SQLite, no MySQL server involved" ;;
                mysql) NA_REASON="not applicable - MySQL runs locally on this same server, see the Database section above" ;;
                *) NA_REASON="not applicable - database type could not be determined" ;;
            esac
            _layout_row "$LABEL" "N/A" "INFO" "INFO" "$NA_REASON"
            continue
        fi

        # 2. Database Type - WARN if sqlite
        if [ "$LABEL" = "Database Type" ] && [ "${DATA[database.type]:-}" = "sqlite" ]; then
            _layout_row "$LABEL" "sqlite" "WARN" "WARN" "SQLite is not recommended for production - use MySQL"
            continue
        fi

        # 3. Configure Archive Backup Settings - disabled = CRITICAL
        if [ "$LABEL" = "Configure Archive Backup Settings" ]; then
            local RAW="${DATA[archive.backup.active]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
            fi
            continue
        fi

        # 4. 2FA - if bypass enabled = WARN
        if [ "$LABEL" = "2FA" ]; then
            local RAW="${DATA[security.login.2fa_bypass_enabled]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _layout_row "$LABEL" "Bypass enabled (2FA off)" "WARN" "WARN" "$NOTE"
            else
                _layout_row "$LABEL" "2FA active" "PASS" "PASS" "$NOTE"
            fi
            continue
        fi

        # 5. Hide Server Version - must be enabled
        if [ "$LABEL" = "Hide Server Version" ]; then
            local RAW="${DATA[smtp.hide_server_version]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
            fi
            continue
        fi

        # 6. Block Outgoing Port 9001 - must be blocked
        if [ "$LABEL" = "Block Outgoing Port 9001" ]; then
            local RAW="${DATA[security.port_9001_egress.blocked]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _layout_row "$LABEL" "Blocked" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "Not Blocked" "CRITICAL" "CRITICAL" "$NOTE"
            fi
            continue
        fi

        # 7. Remove Old AntiSpam Folders
        if [ "$LABEL" = "Remove Old AntiSpam Folders" ]; then
            local STATUS="${DATA[security.cyren_folder.status]:-INFO}"
            local MSG="${DATA[security.cyren_folder.message]:-}"
            local BKIND="INFO"; local BTEXT="INFO"
            case "$STATUS" in
                OK) BKIND="PASS"; BTEXT="PASS" ;;
                WARN) BKIND="WARN"; BTEXT="WARN" ;;
                *) BKIND="INFO"; BTEXT="INFO" ;;
            esac
            _layout_row "$LABEL" "$STATUS" "$BKIND" "$BTEXT" "$MSG"
            continue
        fi

        # 8. Check for Certificates - expiration logic
        if [ "$LABEL" = "Check for Certificates" ]; then
            local EXPIRY="${DATA[icewarp.ssl.expiration]:-}"
            local DAYS_LEFT="${DATA[icewarp.ssl.days_left]:-0}"
            local BKIND="INFO"; local BTEXT="INFO"; local VALUE=""
            if [[ -n "$EXPIRY" ]] && [[ "$EXPIRY" != "N/A" ]] && [[ "$EXPIRY" != "not returned" ]]; then
                VALUE="expires $EXPIRY ($DAYS_LEFT days left)"
                if [[ "$DAYS_LEFT" -gt 90 ]]; then
                    BKIND="PASS"; BTEXT="PASS"
                elif [[ "$DAYS_LEFT" -gt 30 ]]; then
                    BKIND="WARN"; BTEXT="WARN"
                else
                    BKIND="CRITICAL"; BTEXT="CRITICAL"
                fi
            else
                VALUE="N/A"
                BKIND="INFO"; BTEXT="INFO"
            fi
            _layout_row "$LABEL" "$VALUE" "$BKIND" "$BTEXT" "$NOTE"
            continue
        fi

        # 9. Process POP3 / Process IMAP - if 1 then PASS, if 0 then CRITICAL
        if [ "$LABEL" = "Process POP3" ]; then
            local RAW="${DATA[security.intrusion.process_pop3]:-0}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
            fi
            continue
        fi
        if [ "$LABEL" = "Process IMAP" ]; then
            local RAW="${DATA[security.intrusion.process_imap]:-0}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
            fi
            continue
        fi

        # 10. Disable AntiSpam Live
        if [ "$LABEL" = "Disable AntiSpam Live" ]; then
            local RAW="${DATA[security.antispam_live.enabled]:-}"
            if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _layout_row "$LABEL" "YES" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "NO" "WARN" "WARN" "$NOTE"
            fi
            continue
        fi

        # 11. Last Backup Date and Time - check age
        if [ "$LABEL" = "Last Backup Date and Time" ]; then
            local BACKUP_TIME="${DATA[icewarp.backup.last_time]:-}"
            if [ -n "$BACKUP_TIME" ]; then
                local DAYS=$(_days_ago "$BACKUP_TIME")
                local BKIND="INFO"; local BTEXT="INFO"
                if [ "$DAYS" -lt 2 ]; then
                    BKIND="PASS"; BTEXT="PASS"
                elif [ "$DAYS" -lt 4 ]; then
                    BKIND="WARN"; BTEXT="WARN"
                else
                    BKIND="CRITICAL"; BTEXT="CRITICAL"
                fi
                _layout_row "$LABEL" "$BACKUP_TIME ($DAYS days ago)" "$BKIND" "$BTEXT" "Backup age: $DAYS days"
            else
                _layout_row "$LABEL" "Never" "CRITICAL" "CRITICAL" "No backup found"
            fi
            continue
        fi

        # 12. Set customers-stat@parsavan.com - check if email contains customers-stat@parsavan.com
        if [ "$LABEL" = "Set customers-stat@parsavan.com" ]; then
            local RAW="${DATA[monitor.alert_email]:-}"
            if [[ "$RAW" == *"customers-stat@parsavan.com"* ]] || [[ "$RAW" == *"customers-stat"* ]]; then
                _layout_row "$LABEL" "$RAW" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "$RAW" "CRITICAL" "CRITICAL" "Expected: customers-stat@parsavan.com"
            fi
            continue
        fi

        # 13. OS items with watchdog
        if [ "$KIND" = "V" ] && [[ "$KEYS" == *"storage.root_fs.used_percent"* || "$KEYS" == *"os.cpu.load1"* || "$KEYS" == *"os.memory.total_kb"* || "$KEYS" == *"os.last_update_date"* ]]; then
            local WD_INFO="$(_get_watchdog_status "$KEYS")"
            local WD_BKIND="${WD_INFO%%|*}"
            local WD_MSG="${WD_INFO##*|}"
            local VAL="$(_cl_value_render "$KEYS")"
            local NOTE_FINAL="$NOTE"
            [ -n "$WD_MSG" ] && NOTE_FINAL="${NOTE_FINAL} | watchdog: ${WD_MSG}"
            _layout_row "$LABEL" "$VAL" "$WD_BKIND" "$WD_BKIND" "$NOTE_FINAL"
            continue
        fi

        # ----- Generic logic by KIND -----
        case "$KIND" in
            F)
                local RAW="${DATA[$KEYS]:-}"
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _layout_row "$LABEL" "Found" "PASS" "PASS" "$NOTE"
                elif [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                    _layout_row "$LABEL" "Missing" "CRITICAL" "CRITICAL" "$NOTE"
                else
                    _layout_row "$LABEL" "N/A" "INFO" "INFO" "$NOTE"
                fi
                ;;
            B)
                local RAW="${DATA[$KEYS]:-}"
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
                else
                    _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
                fi
                ;;
            R)
                local RAW="${DATA[$KEYS]:-}"
                if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                    _layout_row "$LABEL" "No" "PASS" "PASS" "$NOTE"
                elif [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _layout_row "$LABEL" "Yes" "CRITICAL" "CRITICAL" "$NOTE"
                else
                    _layout_row "$LABEL" "N/A" "INFO" "INFO" "$NOTE"
                fi
                ;;
            V)
                # For MySQL parallel items, if database is sqlite, show N/A
                if [[ "$SECTION" == "Database" ]] && [[ "$LABEL" == "MySQL OS version" || "$LABEL" == "MySQL Disk (Total GB / Used %)" || "$LABEL" == "MySQL CPU Usage" || "$LABEL" == "MySQL RAM (Total KB / Available KB)" || "$LABEL" == "MySQL OS Last Update" || "$LABEL" == "MySQL Repository Access" || "$LABEL" == "MySQL Time Sync" ]] && [ "${DATA[database.type]:-}" != "mysql" ]; then
                    _layout_row "$LABEL" "N/A" "INFO" "INFO" "not applicable - MySQL is not local"
                else
                    local VAL="$(_cl_value_render "$KEYS")"
                    _layout_row "$LABEL" "$VAL" "INFO" "INFO" "$NOTE"
                fi
                ;;
            L)
                local RAW="${DATA[$KEYS]:-}"
                if [[ -n "$RAW" ]] && [[ "$RAW" != "0" ]]; then
                    _layout_row "$LABEL" "Enabled (level $RAW)" "PASS" "PASS" "$NOTE"
                elif [[ "$RAW" == "0" ]]; then
                    _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
                else
                    _layout_row "$LABEL" "N/A" "INFO" "INFO" "$NOTE"
                fi
                ;;
            Z)
                local RAW="${DATA[$KEYS]:-}"
                if [ "$RAW" = "0" ]; then
                    _layout_row "$LABEL" "0 (unlimited)" "WARN" "WARN" "${NOTE:-a limit of 0 means unlimited - consider setting a real value}"
                elif [ -n "$RAW" ]; then
                    _layout_row "$LABEL" "$RAW" "INFO" "INFO" "$NOTE"
                else
                    _layout_row "$LABEL" "not collected" "INFO" "INFO" "$NOTE"
                fi
                ;;
            M)
                local RAW="${DATA[$KEYS]:-}"
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _layout_row "$LABEL" "Yes" "WARN" "WARN" "$NOTE"
                else
                    _layout_row "$LABEL" "No" "PASS" "PASS" "$NOTE"
                fi
                ;;
            G)
                local RAW="${DATA[$KEYS]:-}"
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _layout_row "$LABEL" "Yes" "PASS" "PASS" "$NOTE"
                else
                    _layout_row "$LABEL" "No" "CRITICAL" "CRITICAL" "$NOTE"
                fi
                ;;
            P)
                local RAW="${DATA[$KEYS]:-}"
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _layout_row "$LABEL" "Active" "CRITICAL" "CRITICAL" "$NOTE"
                else
                    _layout_row "$LABEL" "Off" "PASS" "PASS" "$NOTE"
                fi
                ;;
            W)
                local RAW="${DATA[$KEYS]:-}"
                local VALUE="$RAW"
                local DETAIL="$(_render_note_template "$NOTE")"
                _layout_row "$LABEL" "$VALUE" "INFO" "INFO" "$DETAIL"
                ;;
            H)
                local COMBINED="$(_health_worst_of "$KEYS")"
                local BKIND="${COMBINED%%|*}"
                local MSG="${COMBINED#*|}"
                _layout_row "$LABEL" "" "$BKIND" "$BKIND" "${MSG:-$NOTE}"
                ;;
            D)
                # Already handled above
                ;;
            *)
                local RAW="${DATA[$KEYS]:-}"
                if [ -n "$RAW" ]; then
                    _layout_row "$LABEL" "$RAW" "INFO" "INFO" "$NOTE"
                else
                    _layout_row "$LABEL" "N/A" "INFO" "INFO" "$NOTE"
                fi
                ;;
        esac
    done < "$CHECKLIST_FILE"
}

# ---------- Health Summary ----------
_render_health_summary() {
    _layout_section_header "Health Summary"
    _layout_row_index=0
    for K in $(printf '%s\n' "${!HEALTH[@]}" | sort); do
        if [ "$K" = "memory" ] && [ -n "${DATA[watchdog.memory.status]:-}" ]; then
            continue
        fi
        local RESULT="${HEALTH[$K]}"
        local BKIND
        case "$RESULT" in
            pass) BKIND="PASS" ;;
            warn) BKIND="WARN" ;;
            fail) BKIND="CRITICAL" ;;
            *) BKIND="INFO" ;;
        esac
        _layout_row "$K" "" "$BKIND" "$(echo "$RESULT" | tr '[:lower:]' '[:upper:]')" "${HEALTH_MSG[$K]:-}"
    done
    if [ -n "${DATA[watchdog.memory.status]:-}" ]; then
        local STATUS="${DATA[watchdog.memory.status]}"
        local MSG="${DATA[watchdog.memory.message]:-}"
        local BKIND
        case "$STATUS" in
            PASS) BKIND="PASS" ;;
            WARN) BKIND="WARN" ;;
            FAIL) BKIND="CRITICAL" ;;
            *) BKIND="INFO" ;;
        esac
        _layout_row "memory (watchdog)" "" "$BKIND" "$(echo "$STATUS" | tr '[:lower:]' '[:upper:]')" "$MSG"
    fi
}

# ---------- PDF object writers ----------
_pdf_obj() { local NUM="$1"; shift; PDF_OFFSETS[$NUM]="$(wc -c < "$PDF_OUT_FILE")"; printf '%s' "$1" >> "$PDF_OUT_FILE"; }

_pdf_write_file() {
    local OUT_PDF="$1"
    local P="${#_PDF_PAGES[@]}"
    [ "$P" -eq 0 ] && { echo "[WARN] build_pdf: nothing to render" >&2; return 1; }

    local F_REG=$((2 + 2*P + 1))
    local F_BOLD=$((2 + 2*P + 2))
    local F_OBL=$((2 + 2*P + 3))
    declare -Ag PDF_OFFSETS=()
    PDF_OUT_FILE="$OUT_PDF"

    : > "$OUT_PDF"
    printf '%%PDF-1.4\n' >> "$OUT_PDF"

    _pdf_obj 1 "1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
"
    local KIDS=""
    for ((i=1; i<=P; i++)); do KIDS="${KIDS}$((2+i)) 0 R "; done
    _pdf_obj 2 "2 0 obj
<< /Type /Pages /Kids [ ${KIDS}] /Count ${P} >>
endobj
"
    for ((i=1; i<=P; i++)); do
        local PAGE_NUM=$((2+i))
        local CONTENT_NUM=$((2+P+i))
        local STREAM="${_PDF_PAGES[$((i-1))]}"
        local STREAM_LEN="$(printf '%s' "$STREAM" | wc -c)"
        _pdf_obj "$PAGE_NUM" "${PAGE_NUM} 0 obj
<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 ${F_REG} 0 R /F2 ${F_BOLD} 0 R /F3 ${F_OBL} 0 R >> >> /MediaBox [0 0 ${PDF_PAGE_W} ${PDF_PAGE_H}] /Contents ${CONTENT_NUM} 0 R >>
endobj
"
        _pdf_obj "$CONTENT_NUM" "${CONTENT_NUM} 0 obj
<< /Length ${STREAM_LEN} >>
stream
${STREAM}
endstream
endobj
"
    done

    _pdf_obj "$F_REG" "${F_REG} 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
"
    _pdf_obj "$F_BOLD" "${F_BOLD} 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>
endobj
"
    _pdf_obj "$F_OBL" "${F_OBL} 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique >>
endobj
"

    local XREF_START="$(wc -c < "$OUT_PDF")"
    local TOTAL_OBJS=$((F_OBL + 1))
    {
        printf 'xref\n0 %d\n' "$TOTAL_OBJS"
        printf '0000000000 65535 f \n'
        local n
        for ((n=1; n<=F_OBL; n++)); do
            printf '%010d 00000 n \n' "${PDF_OFFSETS[$n]}"
        done
        printf 'trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n' "$TOTAL_OBJS" "$XREF_START"
    } >> "$OUT_PDF"

    echo "[INFO] PDF report written: $OUT_PDF ($(wc -c < "$OUT_PDF") bytes, ${P} page(s))"
}

# ---------- Main build ----------
build_pdf() {
    local OUT_PDF="${OUTPUT_PDF:-${PROJECT_ROOT}/output/report.pdf}"
    _PDF_PAGES=(); _PDF_CUR=""; _PDF_Y=$PDF_TOP_Y

    _layout_cover
    if [ "${#HEALTH[@]}" -gt 0 ] || [ -n "${DATA[watchdog.memory.status]:-}" ]; then
        _render_health_summary
    fi
    _layout_new_page
    _render_checklist

    _layout_new_page
    _layout_section_header "Collector Status"
    local K FAILED_COLLECTORS=0
    _layout_row_index=0
    for K in $(printf '%s\n' "${!STATUS[@]}" | sort); do
        [ "${STATUS[$K]}" = "ok" ] && continue
        FAILED_COLLECTORS=$((FAILED_COLLECTORS+1))
        _layout_row "$K" "${STATUS_MSG[$K]:-}" "INFO" "${STATUS[$K]}" ""
    done
    [ "$FAILED_COLLECTORS" -eq 0 ] && _layout_plain_line "All collectors ran OK"

    _layout_new_page
    _layout_section_header "Appendix: Full Raw Data (${#DATA[@]} keys)"
    for K in $(printf '%s\n' "${!DATA[@]}" | sort); do
        _layout_plain_line "$(printf '%-42s %s' "$K" "${DATA[$K]}")"
    done

    _layout_finish
    _pdf_write_file "$OUT_PDF"
}
