#!/bin/bash

###############################################################################
# =============================================================================
# SECTION 1: HEADER AND LICENSE
# =============================================================================
#
# PDF Report Writer (M5) - FINAL WITH VALIDATION
#
###############################################################################

# =============================================================================
# SECTION 2: CONSTANTS (Page dimensions, colors, margins)
# =============================================================================

PDF_PAGE_W=612
PDF_PAGE_H=792
PDF_MARGIN=36
PDF_TOP_Y=756
PDF_BOTTOM_Y=44
PDF_CONTENT_RIGHT=$((PDF_PAGE_W - PDF_MARGIN))
PDF_CONTENT_W=$((PDF_CONTENT_RIGHT - PDF_MARGIN))

PDF_C_NAVY="0.102 0.235 0.369"
PDF_C_WHITE="1 1 1"
PDF_C_TEXT="0.15 0.17 0.2"
PDF_C_GRAY_LIGHT="0.955 0.96 0.965"
PDF_C_GREEN="0.118 0.518 0.286"
PDF_C_RED="0.753 0.224 0.169"
PDF_C_AMBER="0.83 0.53 0.06"
PDF_C_BLUEGRAY="0.30 0.42 0.55"
PDF_C_GRAY="0.5 0.53 0.56"

# =============================================================================
# SECTION 3: HELPER FUNCTIONS
# =============================================================================

_is_num() { [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; }

_pdf_escape() {
    local S="$1"
    S="$(printf '%s' "$S" | LC_ALL=C tr -c '\40-\176' '?')"
    S="${S//\\/\\\\}"
    S="${S//(/\\(}"
    S="${S//)/\\)}"
    printf '%s' "$S"
}

_pdf_rect() {
    _PDF_CUR="${_PDF_CUR}${5} rg"$'\n'
    _PDF_CUR="${_PDF_CUR}${1} ${2} ${3} ${4} re f"$'\n'
}

_pdf_text() {
    local ESC
    ESC="$(_pdf_escape "$3")"
    _PDF_CUR="${_PDF_CUR}${6} rg"$'\n'
    _PDF_CUR="${_PDF_CUR}BT /${4} ${5} Tf ${1} ${2} Td (${ESC}) Tj ET"$'\n'
}

_pdf_text_trunc() {
    local MAXCHARS="$7"
    local TXT="$3"
    [ "${#TXT}" -gt "$MAXCHARS" ] && TXT="${TXT:0:$((MAXCHARS-1))}."
    _pdf_text "$1" "$2" "$TXT" "$4" "$5" "$6"
}

# =============================================================================
# SECTION 4: PAGE MANAGEMENT
# =============================================================================

_PDF_PAGES=()
_PDF_CUR=""
_PDF_Y=$PDF_TOP_Y

_layout_new_page() {
    [ -n "$_PDF_CUR" ] && _PDF_PAGES+=("$_PDF_CUR")
    _PDF_CUR=""
    _PDF_Y=$PDF_TOP_Y
}

_layout_ensure() {
    local NEEDED="$1"
    [ "$((_PDF_Y - NEEDED))" -lt "$PDF_BOTTOM_Y" ] && _layout_new_page
}

_layout_finish() {
    [ -n "$_PDF_CUR" ] && _PDF_PAGES+=("$_PDF_CUR")
}

_layout_section_header() {
    local TITLE="$1"
    _layout_ensure 46
    _PDF_Y=$((_PDF_Y - 6))
    _pdf_rect "$PDF_MARGIN" "$((_PDF_Y - 18))" "$PDF_CONTENT_W" 22 "$PDF_C_NAVY"
    _pdf_text "$((PDF_MARGIN + 8))" "$((_PDF_Y - 12))" "$TITLE" "F2" 11 "$PDF_C_WHITE"
    _PDF_Y=$((_PDF_Y - 30))
}

# =============================================================================
# SECTION 5: BADGE COLOR AND ROW RENDERER
# =============================================================================

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
    local ROW_H=16
    [ -n "$NOTE" ] && ROW_H=27
    _layout_ensure "$ROW_H"
    local BG="$PDF_C_WHITE"
    [ $(( _layout_row_index % 2 )) -eq 1 ] && BG="$PDF_C_GRAY_LIGHT"
    _layout_row_index=$((_layout_row_index + 1))
    local ROW_TOP=$_PDF_Y
    _pdf_rect "$PDF_MARGIN" "$((ROW_TOP - ROW_H + 4))" "$PDF_CONTENT_W" "$ROW_H" "$BG"
    local TEXT_Y=$((ROW_TOP - 11))
    _pdf_text_trunc "$((PDF_MARGIN + 8))" "$TEXT_Y" "$LABEL" "F1" 9 "$PDF_C_TEXT" 46
    _pdf_text_trunc "$((PDF_MARGIN + 240))" "$TEXT_Y" "$VALUE" "F1" 9 "$PDF_C_GRAY" 34
    local BADGE_W=76 BADGE_H=13
    local BADGE_X=$((PDF_CONTENT_RIGHT - BADGE_W - 4))
    local BADGE_Y=$((ROW_TOP - 12))
    local BCOLOR
    BCOLOR="$(_badge_color "$BKIND")"
    _pdf_rect "$BADGE_X" "$BADGE_Y" "$BADGE_W" "$BADGE_H" "$BCOLOR"
    _pdf_text_trunc "$((BADGE_X + 6))" "$((BADGE_Y + 4))" "$BTEXT" "F2" 7.5 "$PDF_C_WHITE" 14
    [ -n "$NOTE" ] && _pdf_text_trunc "$((PDF_MARGIN + 8))" "$((TEXT_Y - 11))" "note: ${NOTE}" "F3" 7.5 "$PDF_C_GRAY" 100
    _PDF_Y=$((_PDF_Y - ROW_H))
}

_layout_plain_line() {
    _layout_ensure 12
    _pdf_text_trunc "$PDF_MARGIN" "$_PDF_Y" "$1" "F1" 8.5 "$PDF_C_TEXT" 110
    _PDF_Y=$((_PDF_Y - 12))
}

# =============================================================================
# SECTION 6: COVER PAGE
# =============================================================================

_layout_cover() {
    local HOST="${DATA[agent.hostname]:-unknown}"
    local GEN="${DATA[agent.time]:-unknown}"
    local VER="${DATA[agent.version]:-unknown}"
    local OVERALL="${DATA[health.summary.overall]:-n/a}"
    local FAILED="${DATA[health.summary.failed]:-0}"
    local WARNINGS="${DATA[health.summary.warnings]:-0}"
    local CHECKED="${DATA[health.summary.total_checks]:-0}"

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
    local ROW
    for ROW in "${INFO_ROWS[@]}"; do
        local LBL="${ROW%%|*}"
        local VAL="${ROW#*|}"
        _pdf_text "$((PDF_MARGIN + 8))" "$_PDF_Y" "${LBL}:" "F2" 9.5 "$PDF_C_TEXT"
        _pdf_text_trunc "$((PDF_MARGIN + 190))" "$_PDF_Y" "$VAL" "F1" 9.5 "$PDF_C_GRAY" 55
        _PDF_Y=$((_PDF_Y - 16))
    done

    _PDF_Y=$((_PDF_Y - 14))
    local BANNER_COLOR
    case "$OVERALL" in
        pass) BANNER_COLOR="$PDF_C_GREEN" ;;
        warn) BANNER_COLOR="$PDF_C_AMBER" ;;
        fail) BANNER_COLOR="$PDF_C_RED" ;;
        *) BANNER_COLOR="$PDF_C_GRAY" ;;
    esac
    _pdf_rect "$PDF_MARGIN" "$((_PDF_Y - 44))" "$PDF_CONTENT_W" 44 "$BANNER_COLOR"
    _pdf_text "$((PDF_MARGIN + 14))" "$((_PDF_Y - 20))" "OVERALL: $(echo "$OVERALL" | tr '[:lower:]' '[:upper:]')" "F2" 15 "$PDF_C_WHITE"
    _pdf_text "$((PDF_MARGIN + 14))" "$((_PDF_Y - 36))" "${CHECKED} checks run  -  ${FAILED} failed  -  ${WARNINGS} warnings" "F1" 9.5 "$PDF_C_WHITE"
    _PDF_Y=$((_PDF_Y - 60))

    _pdf_text "$PDF_MARGIN" "$_PDF_Y" "Legend:" "F2" 8.5 "$PDF_C_TEXT"
    local LX=$((PDF_MARGIN + 46))
    local LEGEND_ITEMS=("PASS:Green" "CRITICAL:Red" "WARN:Orange" "INFO:Purple")
    local ITEM
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

# =============================================================================
# SECTION 7: HEALTH SUMMARY RENDERER
# =============================================================================

_render_health_summary() {
    _layout_section_header "Health Summary"
    _layout_row_index=0

    local -a SUMMARY_ITEMS=(
        "backup.auto|Backup"
        "memory|Resource - RAM"
        "cpu|Resource - CPU"
        "disk.root_fs|Resource - HDD"
        "disk.install|Resource - HDD"
        "disk.mail|Resource - HDD"
        "disk.archive|Resource - HDD"
        "disk.root_home|Resource - HDD"
        "login_blocking|Login Blocking"
        "tls_delivery|SSL"
        "os_update|OS Update"
        "password_policy|Password Policy"
    )

    for ITEM in "${SUMMARY_ITEMS[@]}"; do
        local KEY="${ITEM%%|*}"
        local TITLE="${ITEM##*|}"
        local RESULT="${HEALTH[$KEY]:-skip}"
        [ "$RESULT" = "skip" ] && continue
        local BKIND
        case "$RESULT" in
            pass) BKIND="PASS" ;;
            warn) BKIND="WARN" ;;
            fail|critical) BKIND="CRITICAL" ;;
            *) BKIND="INFO" ;;
        esac
        _layout_row "$TITLE" "" "$BKIND" "$BKIND" "${HEALTH_MSG[$KEY]:-}"
    done
}

# =============================================================================
# SECTION 8: DATE, VALUE RENDER, INTRUSION VALIDATION HELPERS
# =============================================================================

_days_ago() {
    local date_str="$1"
    [[ -z "$date_str" ]] && echo "999"
    local date_epoch
    date_epoch="$(date -d "$date_str" +%s 2>/dev/null)"
    [[ -z "$date_epoch" ]] && echo "999"
    echo $(( ( $(date +%s) - date_epoch ) / 86400 ))
}

_cl_value_render() {
    local KEYS="$1"
    if [[ "$KEYS" == *,* ]]; then
        local -a PARTS=()
        local K SHORT
        IFS=',' read -ra _KARR <<< "$KEYS"
        for K in "${_KARR[@]}"; do
            SHORT="${K##*.}"
            PARTS+=("${SHORT}=${DATA[$K]:-?}")
        done
        local JOINED
        JOINED="$(IFS=', '; echo "${PARTS[*]}")"
        printf '%s' "$JOINED"
    else
        printf '%s' "${DATA[$KEYS]:-(empty)}"
    fi
}

_validate_intrusion_value() {
    local KEY="$1"
    local VALUE="$2"
    local EXPECTED=""
    local BKIND="INFO"
    local BTEXT="INFO"
    local NOTE=""

    case "$KEY" in
        "security.intrusion.block_connections_per_minute.value")
            EXPECTED="10"
            ;;
        "security.intrusion.block_unknown_user_count.value")
            EXPECTED="5"
            ;;
        "security.intrusion.block_relay_denied_count.value")
            EXPECTED="5"
            ;;
        "security.intrusion.block_rset_count.value")
            EXPECTED="5"
            ;;
        "security.intrusion.block_spam_score.value")
            EXPECTED="9.00"
            ;;
        "security.intrusion.block_failed_logins.value")
            EXPECTED="5"
            ;;
        "security.intrusion.block_duration_minutes")
            EXPECTED="30"
            ;;
        *)
            printf 'INFO|INFO|%s' "$VALUE"
            return
            ;;
    esac

    if [ -z "$VALUE" ]; then
        BKIND="CRITICAL"
        BTEXT="CRITICAL"
        NOTE="Setting not found"
    elif [[ "$VALUE" == "$EXPECTED" ]]; then
        BKIND="PASS"
        BTEXT="PASS"
        NOTE="Expected: $EXPECTED"
    else
        BKIND="WARN"
        BTEXT="WARN"
        NOTE="Expected: $EXPECTED (current: $VALUE)"
    fi

    printf '%s|%s|%s' "$BKIND" "$BTEXT" "$NOTE"
}

# =============================================================================
# SECTION 9: MAIN CHECKLIST RENDERER
# =============================================================================

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

        # ---- Special case: MySQL Server section ----
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

        # ---- Special case: MySQL items in Database section ----
        if [[ "$SECTION" == "Database" ]] && [[ "$LABEL" == MySQL* ]] && [[ "${DATA[mysql.applicable]:-false}" != "true" ]]; then
            _layout_row "$LABEL" "N/A" "INFO" "INFO" "MySQL is not installed/running on this server"
            continue
        fi

        # ---- Special case: Database Type ----
        if [ "$LABEL" = "Database Type" ] && [ "${DATA[database.type]:-}" = "sqlite" ]; then
            _layout_row "$LABEL" "sqlite" "WARN" "WARN" "SQLite is not recommended for production - use MySQL"
            continue
        fi

        # ---- Special case: customers-stat email ----
        if [ "$LABEL" = "Set customers-stat@parsavan.com" ]; then
            local RAW="${DATA[monitor.alert_email]:-}"
            if [[ "$RAW" == *"customers-stat@parsavan.com"* ]] || [[ "$RAW" == *"customers-stat"* ]]; then
                _layout_row "$LABEL" "$RAW" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "$RAW" "CRITICAL" "CRITICAL" "Expected: customers-stat@parsavan.com"
            fi
            continue
        fi

        # ---- Special case: Certificates ----
        if [ "$LABEL" = "Check for Certificates" ]; then
            local EXPIRY="${DATA[icewarp.ssl.expiration]:-}"
            local DAYS_LEFT="${DATA[icewarp.ssl.days_left]:-0}"
            local BKIND="INFO"
            local BTEXT="INFO"
            local VALUE=""
            if [[ -n "$EXPIRY" ]] && [[ "$EXPIRY" != "N/A" ]] && [[ "$EXPIRY" != "not returned" ]]; then
                VALUE="expires $EXPIRY ($DAYS_LEFT days left)"
                if [[ "$DAYS_LEFT" -gt 90 ]]; then
                    BKIND="PASS"
                    BTEXT="PASS"
                elif [[ "$DAYS_LEFT" -gt 30 ]]; then
                    BKIND="WARN"
                    BTEXT="WARN"
                else
                    BKIND="CRITICAL"
                    BTEXT="CRITICAL"
                fi
            else
                VALUE="N/A"
                BKIND="INFO"
                BTEXT="INFO"
            fi
            _layout_row "$LABEL" "$VALUE" "$BKIND" "$BTEXT" "$NOTE"
            continue
        fi

        # ---- Special case: Last Backup Date ----
        if [ "$LABEL" = "Last Backup Date and Time" ]; then
            local BACKUP_TIME="${DATA[icewarp.backup.last_time]:-}"
            if [ -n "$BACKUP_TIME" ]; then
                local DAYS=$(_days_ago "$BACKUP_TIME")
                local BKIND="INFO"
                local BTEXT="INFO"
                if [ "$DAYS" -lt 2 ]; then
                    BKIND="PASS"
                    BTEXT="PASS"
                elif [ "$DAYS" -lt 4 ]; then
                    BKIND="WARN"
                    BTEXT="WARN"
                else
                    BKIND="CRITICAL"
                    BTEXT="CRITICAL"
                fi
                _layout_row "$LABEL" "$BACKUP_TIME ($DAYS days ago)" "$BKIND" "$BTEXT" "Backup age: $DAYS days"
            else
                _layout_row "$LABEL" "Never" "CRITICAL" "CRITICAL" "No backup found"
            fi
            continue
        fi

        # ---- Special case: 2FA ----
        if [ "$LABEL" = "2FA" ]; then
            local RAW="${DATA[security.login.2fa_bypass_enabled]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _layout_row "$LABEL" "Bypass enabled (2FA off)" "WARN" "WARN" "$NOTE"
            else
                _layout_row "$LABEL" "2FA active" "PASS" "PASS" "$NOTE"
            fi
            continue
        fi

        # ---- Special case: Hide Server Version ----
        if [ "$LABEL" = "Hide Server Version" ]; then
            local RAW="${DATA[smtp.hide_server_version]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
            fi
            continue
        fi

        # ---- Special case: Port 9001 ----
        if [ "$LABEL" = "Block Outgoing Port 9001" ]; then
            local RAW="${DATA[security.port_9001_egress.blocked]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _layout_row "$LABEL" "Blocked" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "Not Blocked" "CRITICAL" "CRITICAL" "$NOTE"
            fi
            continue
        fi

        # ---- Special case: AntiSpam Folders ----
        if [ "$LABEL" = "Remove Old AntiSpam Folders" ]; then
            local STATUS="${DATA[security.cyren_folder.status]:-INFO}"
            local MSG="${DATA[security.cyren_folder.message]:-}"
            local BKIND="INFO"
            local BTEXT="INFO"
            case "$STATUS" in
                OK) BKIND="PASS"; BTEXT="PASS" ;;
                WARN) BKIND="WARN"; BTEXT="WARN" ;;
                *) BKIND="INFO"; BTEXT="INFO" ;;
            esac
            _layout_row "$LABEL" "$STATUS" "$BKIND" "$BTEXT" "$MSG"
            continue
        fi

        # ---- Special case: AntiSpam Live ----
        if [ "$LABEL" = "Disable AntiSpam Live" ]; then
            local RAW="${DATA[security.antispam_live.enabled]:-}"
            if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _layout_row "$LABEL" "YES" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "NO" "WARN" "WARN" "$NOTE"
            fi
            continue
        fi

        # ---- Special case: Process POP3/IMAP ----
        if [ "$LABEL" = "Process POP3/IMAP" ]; then
            local RAW="${DATA[security.intrusion.process_pop3_imap]:-0}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
            fi
            continue
        fi

        # ---- Special case: Cloud Features (CHANGED to WARN for enabled) ----
        if [ "$LABEL" = "Disable Cloud Features" ]; then
            local RAW="${DATA[icewarp.cloud_api.autoconfigure]:-}"
            if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _layout_row "$LABEL" "Disabled" "PASS" "PASS" "$NOTE"
            elif [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _layout_row "$LABEL" "Enabled" "WARN" "WARN" "$NOTE"
            else
                _layout_row "$LABEL" "N/A" "INFO" "INFO" "$NOTE"
            fi
            continue
        fi

        # ---- Special case: DIGEST-MD5 ----
        if [ "$LABEL" = "Disable DIGEST-MD5" ]; then
            local RAW="${DATA[security.digest_md5.enabled]:-}"
            if [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _layout_row "$LABEL" "Disabled" "PASS" "PASS" "$NOTE"
            elif [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _layout_row "$LABEL" "Enabled" "CRITICAL" "CRITICAL" "$NOTE"
            else
                _layout_row "$LABEL" "N/A" "INFO" "INFO" "$NOTE"
            fi
            continue
        fi

        # ---- Special case: IMAP / POP3 ----
        if [ "$LABEL" = "Disable IMAP" ] || [ "$LABEL" = "Disable POP3" ]; then
            local RAW="${DATA[${KEYS}]:-0}"
            if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _layout_row "$LABEL" "Disabled" "PASS" "PASS" "${NOTE:-If service is needed, enable it; otherwise disabled is secure}"
            else
                _layout_row "$LABEL" "Enabled" "PASS" "PASS" "${NOTE:-Service is enabled - ensure it is required}"
            fi
            continue
        fi

        # ---- Special case: VRFY ----
        if [ "$LABEL" = "Disable VRFY" ]; then
            local RAW="${DATA[smtp.deny_vrfy]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _layout_row "$LABEL" "Disabled" "PASS" "PASS" "$NOTE"
            elif [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _layout_row "$LABEL" "Enabled" "CRITICAL" "CRITICAL" "$NOTE"
            else
                _layout_row "$LABEL" "Unknown" "CRITICAL" "CRITICAL" "VRFY setting not detected - please verify manually"
            fi
            continue
        fi

        # ---- Special case: License ----
        if [ "$LABEL" = "Number of Used Seats / License Max Users" ]; then
            local RAW="${DATA[icewarp.license.used_seats_note]:-}"
            if [ -z "$RAW" ] || [[ "$RAW" == *"not available"* ]]; then
                _layout_row "$LABEL" "unavailable" "WARN" "WARN" "Unable to retrieve license usage - check via Admin API"
            else
                _layout_row "$LABEL" "$RAW" "INFO" "INFO" "$NOTE"
            fi
            continue
        fi

        # ---- Special case: Daytime Clock ----
        if [ "$LABEL" = "Enable Daytime Clock Synchronization" ]; then
            local RAW="${DATA[icewarp.daytime_clock_sync.enabled]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
            elif [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
            else
                _layout_row "$LABEL" "Unknown" "WARN" "WARN" "Daytime sync setting not detected - please verify manually"
            fi
            continue
        fi

        # ---- Special case: System Backup ----
        if [ "$LABEL" = "Enable System Backup" ]; then
            local RAW="${DATA[icewarp.backup.auto_enabled]:-0}"
            if [ "$RAW" = "1" ]; then
                _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
            fi
            continue
        fi

        # ---- Special case: Database Backup (legacy) ----
        if [ "$LABEL" = "Enable Database Backup" ]; then
            local RAW="${DATA[icewarp.database_backup.enabled]:-0}"
            if [ "$RAW" = "1" ]; then
                _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
            fi
            continue
        fi

        # ---- Special case: Maximum Threads ----
        if [ "$LABEL" = "Maximum Number of Simultaneous Threads" ]; then
            local RAW="${DATA[smtp.incoming_queue_threads]:-}"
            local BKIND="INFO"
            local BTEXT="INFO"
            local MSG=""
            if [ -z "$RAW" ]; then
                BKIND="CRITICAL"; BTEXT="CRITICAL"; MSG="Setting not found"
            elif [ "$RAW" = "10" ]; then
                BKIND="PASS"; BTEXT="PASS"; MSG="Expected: 10 (OK)"
            else
                BKIND="WARN"; BTEXT="WARN"; MSG="Expected: 10 (current: $RAW)"
            fi
            _layout_row "$LABEL" "$RAW" "$BKIND" "$BTEXT" "$MSG"
            continue
        fi

        # ---- Special case: Directory Cache ----
        if [ "$LABEL" = "Set Directory Cache Schedule" ]; then
            local RAW="${DATA[directory_cache.scheduled]:-}"
            local BKIND="INFO"
            local BTEXT="INFO"
            local MSG=""
            if [ "$RAW" = "1" ] || [ "$RAW" = "true" ]; then
                BKIND="PASS"; BTEXT="PASS"; MSG="Schedule is configured"
            else
                BKIND="CRITICAL"; BTEXT="CRITICAL"; MSG="Schedule is NOT configured"
            fi
            _layout_row "$LABEL" "$RAW" "$BKIND" "$BTEXT" "$MSG"
            continue
        fi

        # ---- Watchdog items (main + individual) ----
        if [ "$LABEL" = "Enable System Watchdog" ]; then
            local CTRL="${DATA[watchdog.control]:-0}"
            if [ "$CTRL" = "1" ]; then
                _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
            fi
            continue
        fi

        if [ "$LABEL" = "Watchdog - SMTP" ]; then
            local VAL="${DATA[watchdog.smtp]:-0}"
            if [ "$VAL" = "1" ]; then
                _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
            fi
            continue
        fi

        if [ "$LABEL" = "Watchdog - POP3/IMAP" ]; then
            local VAL="${DATA[watchdog.pop3]:-0}"
            if [ "$VAL" = "1" ]; then
                _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
            fi
            continue
        fi

        if [ "$LABEL" = "Watchdog - IM/VoIP" ]; then
            local VAL="${DATA[watchdog.im]:-0}"
            if [ "$VAL" = "1" ]; then
                _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
            fi
            continue
        fi

        if [ "$LABEL" = "Watchdog - GroupWare" ]; then
            local VAL="${DATA[watchdog.gw]:-0}"
            if [ "$VAL" = "1" ]; then
                _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
            else
                _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
            fi
            continue
        fi

        if [ "$LABEL" = "Watchdog Interval" ]; then
            local INTERVAL="${DATA[watchdog.interval_minutes]:-0}"
            local BKIND="INFO"
            local BTEXT="INFO"
            local MSG=""
            if [ "$INTERVAL" -eq 0 ]; then
                BKIND="PASS"; BTEXT="PASS"; MSG="Every minute (0) - optimal"
            elif [ "$INTERVAL" -ge 1 ] && [ "$INTERVAL" -le 60 ]; then
                BKIND="PASS"; BTEXT="PASS"; MSG="${INTERVAL} minutes (optimal)"
            elif [ "$INTERVAL" -gt 60 ] && [ "$INTERVAL" -le 1440 ]; then
                BKIND="WARN"; BTEXT="WARN"; MSG="${INTERVAL} minutes (>1h - consider reducing)"
            else
                BKIND="CRITICAL"; BTEXT="CRITICAL"; MSG="${INTERVAL} minutes (invalid)"
            fi
            _layout_row "$LABEL" "$INTERVAL" "$BKIND" "$BTEXT" "$MSG"
            continue
        fi

        # ---- NEW: Special case for Integrate Archive with IMAP Folder (show value) ----
        if [ "$LABEL" = "Integrate Archive with IMAP Folder" ]; then
            local RAW="${DATA[archive.integrate_with_imap]:-0}"
            local VALUE=""
            local BKIND="INFO"
            local BTEXT="INFO"
            local MSG=""
            if [ "$RAW" = "1" ]; then
                BKIND="PASS"; BTEXT="PASS"
                VALUE="Enabled"
                MSG="Integrate archive with IMAP folder: Archive"
            else
                BKIND="CRITICAL"; BTEXT="CRITICAL"
                VALUE="Disabled"
                MSG="Integrate archive with IMAP folder: Disabled"
            fi
            _layout_row "$LABEL" "$VALUE" "$BKIND" "$BTEXT" "$MSG"
            continue
        fi

        # ============================================================
        # IMPORTANT: Intrusion Prevention validation
        # MUST be checked BEFORE general KIND=V handling
        # ============================================================
        if [ "$KIND" = "V" ] && [[ "$KEYS" == security.intrusion.*.value* || "$KEYS" == "security.intrusion.block_duration_minutes" ]]; then
            local RAW="${DATA[$KEYS]:-}"
            local VALIDATION
            VALIDATION="$(_validate_intrusion_value "$KEYS" "$RAW" "$LABEL")"
            local BKIND="${VALIDATION%%|*}"
            local BTEXT="$(echo "$VALIDATION" | cut -d'|' -f2)"
            local NOTE_VALID="$(echo "$VALIDATION" | cut -d'|' -f3-)"
            local VALUE="$RAW"
            local FINAL_NOTE="$NOTE"
            [ -n "$NOTE_VALID" ] && FINAL_NOTE="${FINAL_NOTE}${FINAL_NOTE:+ | }${NOTE_VALID}"
            _layout_row "$LABEL" "$VALUE" "$BKIND" "$BTEXT" "$FINAL_NOTE"
            continue
        fi

        # ============================================================
        # APP OS / Infrastructure items (KIND=V with specific LABELs)
        # ============================================================
        if [ "$KIND" = "V" ]; then
            case "$LABEL" in
                "Disk (Total GB / Used %)")
                    local TOTAL_GB="${DATA[storage.root_fs.total_gb]:-0}"
                    local USED_PERCENT="${DATA[storage.root_fs.used_percent]:-0}"
                    local VALUE="total_gb=${TOTAL_GB},used_percent=${USED_PERCENT}"
                    local BKIND="PASS"
                    local BTEXT="PASS"
                    local MSG=""
                    if _is_num "$USED_PERCENT"; then
                        if [ "$USED_PERCENT" -ge 95 ]; then
                            BKIND="CRITICAL"; BTEXT="CRITICAL"; MSG="Disk usage is ${USED_PERCENT}% (CRITICAL - above 95%)"
                        elif [ "$USED_PERCENT" -ge 80 ]; then
                            BKIND="WARN"; BTEXT="WARN"; MSG="Disk usage is ${USED_PERCENT}% (WARN - above 80%)"
                        else
                            BKIND="PASS"; BTEXT="PASS"; MSG="Disk usage is ${USED_PERCENT}% (OK)"
                        fi
                    else
                        MSG="Unable to calculate disk usage percentage"
                    fi
                    _layout_row "$LABEL" "$VALUE" "$BKIND" "$BTEXT" "$MSG"
                    continue
                    ;;
                "CPU Usage")
                    local LOAD15="${DATA[os.cpu.load15]:-0}"
                    local CORES="${DATA[os.cpu.count]:-1}"
                    local CPU_PERCENT=0
                    local VALUE="$LOAD15"
                    local BKIND="PASS"
                    local BTEXT="PASS"
                    local MSG=""
                    if _is_num "$LOAD15" && _is_num "$CORES" && [ "$CORES" -gt 0 ]; then
                        CPU_PERCENT=$(awk -v l="$LOAD15" -v c="$CORES" 'BEGIN{printf "%.2f", (l/c)*100}')
                        local CRIT_LIMIT=$(awk 'BEGIN{print 95}')
                        local WARN_LIMIT=$(awk 'BEGIN{print 50}')
                        if awk -v cpu="$CPU_PERCENT" -v lim="$CRIT_LIMIT" 'BEGIN{exit !(cpu > lim)}'; then
                            BKIND="CRITICAL"; BTEXT="CRITICAL"; MSG="CPU load is ${CPU_PERCENT}% (CRITICAL - above 95%)"
                        elif awk -v cpu="$CPU_PERCENT" -v lim="$WARN_LIMIT" 'BEGIN{exit !(cpu > lim)}'; then
                            BKIND="WARN"; BTEXT="WARN"; MSG="CPU load is ${CPU_PERCENT}% (WARN - above 50%)"
                        else
                            BKIND="PASS"; BTEXT="PASS"; MSG="CPU load is ${CPU_PERCENT}% (OK)"
                        fi
                    else
                        MSG="Unable to calculate CPU load percentage"
                    fi
                    _layout_row "$LABEL" "$VALUE" "$BKIND" "$BTEXT" "$MSG"
                    continue
                    ;;
                "RAM (Total KB / Available KB)")
                    local TOTAL_KB="${DATA[os.memory.total_kb]:-0}"
                    local AVAIL_KB="${DATA[os.memory.available_kb]:-0}"
                    local VALUE="total_kb=${TOTAL_KB},available_kb=${AVAIL_KB}"
                    local BKIND="PASS"
                    local BTEXT="PASS"
                    local MSG=""
                    if _is_num "$TOTAL_KB" && _is_num "$AVAIL_KB" && [ "$TOTAL_KB" -gt 0 ]; then
                        local USED_PERCENT=$(awk -v t="$TOTAL_KB" -v a="$AVAIL_KB" 'BEGIN{printf "%.2f", ((t-a)/t)*100}')
                        local CRIT_LIMIT=$(awk 'BEGIN{print 90}')
                        local WARN_LIMIT=$(awk 'BEGIN{print 40}')
                        if awk -v used="$USED_PERCENT" -v lim="$CRIT_LIMIT" 'BEGIN{exit !(used > lim)}'; then
                            BKIND="CRITICAL"; BTEXT="CRITICAL"; MSG="RAM usage is ${USED_PERCENT}% (CRITICAL - above 90%)"
                        elif awk -v used="$USED_PERCENT" -v lim="$WARN_LIMIT" 'BEGIN{exit !(used > lim)}'; then
                            BKIND="WARN"; BTEXT="WARN"; MSG="RAM usage is ${USED_PERCENT}% (WARN - above 40%)"
                        else
                            BKIND="PASS"; BTEXT="PASS"; MSG="RAM usage is ${USED_PERCENT}% (OK)"
                        fi
                    else
                        MSG="Unable to calculate RAM usage percentage"
                    fi
                    _layout_row "$LABEL" "$VALUE" "$BKIND" "$BTEXT" "$MSG"
                    continue
                    ;;
                "APP OS Last Update")
                    local LAST_UPDATE="${DATA[os.last_update_date]:-}"
                    local VALUE="${LAST_UPDATE:-unknown}"
                    local BKIND="INFO"
                    local BTEXT="INFO"
                    local MSG=""
                    if [ -n "$LAST_UPDATE" ] && [ "$LAST_UPDATE" != "N/A" ] && [ "$LAST_UPDATE" != "null" ]; then
                        local DAYS=$(_days_ago "$LAST_UPDATE")
                        if [ "$DAYS" -le 7 ]; then
                            BKIND="PASS"; BTEXT="PASS"; MSG="OS updated recently (${DAYS} days ago)"
                        elif [ "$DAYS" -le 30 ]; then
                            BKIND="WARN"; BTEXT="WARN"; MSG="OS update is ${DAYS} days old (consider updating)"
                        else
                            BKIND="CRITICAL"; BTEXT="CRITICAL"; MSG="OS is outdated (${DAYS} days since last update)"
                        fi
                    else
                        MSG="OS last update date not available"
                    fi
                    _layout_row "$LABEL" "$VALUE" "$BKIND" "$BTEXT" "$MSG"
                    continue
                    ;;
                "Swap Usage (7 days)")
                    local STATUS="${DATA[system.swap.status]:-INFO}"
                    local MSG="${DATA[system.swap.message]:-}"
                    local BKIND="INFO"
                    local BTEXT="INFO"
                    case "$STATUS" in
                        PASS) BKIND="PASS"; BTEXT="PASS" ;;
                        CRITICAL) BKIND="CRITICAL"; BTEXT="CRITICAL" ;;
                        *) BKIND="INFO"; BTEXT="INFO" ;;
                    esac
                    _layout_row "$LABEL" "${DATA[system.swap.used_percent]:-0}%" "$BKIND" "$BTEXT" "$MSG"
                    continue
                    ;;
            esac
            # Fallback for generic V items
            local VAL="$(_cl_value_render "$KEYS")"
            _layout_row "$LABEL" "$VAL" "INFO" "INFO" "$NOTE"
            continue
        fi

        # ============================================================
        # Other KIND types (T, F, B, R, L, Z, M, G, P, W, D, H, etc.)
        # ============================================================

        if [ "$KIND" = "T" ]; then
            local RAW="${DATA[$KEYS]:-}"
            local EXPECTED="$NOTE"
            local BKIND="INFO"
            local BTEXT="INFO"
            local MSG=""
            if [ "$RAW" = "$EXPECTED" ]; then
                BKIND="PASS"
                BTEXT="PASS"
                MSG="Expected: $EXPECTED"
            else
                BKIND="WARN"
                BTEXT="WARN"
                MSG="Expected: $EXPECTED (current: $RAW)"
            fi
            _layout_row "$LABEL" "$RAW" "$BKIND" "$BTEXT" "$MSG"
            continue
        fi

        local RAW="${DATA[$KEYS]:-}"
        case "$KIND" in
            F)
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _layout_row "$LABEL" "Found" "PASS" "PASS" "$NOTE"
                elif [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                    _layout_row "$LABEL" "Missing" "CRITICAL" "CRITICAL" "$NOTE"
                else
                    _layout_row "$LABEL" "N/A" "INFO" "INFO" "$NOTE"
                fi
                ;;
            B)
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _layout_row "$LABEL" "Enabled" "PASS" "PASS" "$NOTE"
                else
                    _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
                fi
                ;;
            R)
                if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                    _layout_row "$LABEL" "No" "PASS" "PASS" "$NOTE"
                elif [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _layout_row "$LABEL" "Yes" "CRITICAL" "CRITICAL" "$NOTE"
                else
                    _layout_row "$LABEL" "N/A" "INFO" "INFO" "$NOTE"
                fi
                ;;
            L)
                if [[ -n "$RAW" ]] && [[ "$RAW" != "0" ]]; then
                    _layout_row "$LABEL" "Enabled (level $RAW)" "PASS" "PASS" "$NOTE"
                elif [[ "$RAW" == "0" ]]; then
                    _layout_row "$LABEL" "Disabled" "CRITICAL" "CRITICAL" "$NOTE"
                else
                    _layout_row "$LABEL" "N/A" "INFO" "INFO" "$NOTE"
                fi
                ;;
            Z)
                if [ "$RAW" = "0" ]; then
                    _layout_row "$LABEL" "Disabled" "WARN" "WARN" "${NOTE:-Backup emails is disabled (WARN)}"
                elif [ -n "$RAW" ]; then
                    _layout_row "$LABEL" "$RAW" "INFO" "INFO" "$NOTE"
                else
                    _layout_row "$LABEL" "not collected" "INFO" "INFO" "$NOTE"
                fi
                ;;
            M)
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _layout_row "$LABEL" "Yes" "WARN" "WARN" "$NOTE"
                else
                    _layout_row "$LABEL" "No" "PASS" "PASS" "$NOTE"
                fi
                ;;
            G)
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _layout_row "$LABEL" "Yes" "PASS" "PASS" "$NOTE"
                else
                    _layout_row "$LABEL" "No" "CRITICAL" "CRITICAL" "$NOTE"
                fi
                ;;
            P)
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _layout_row "$LABEL" "Active" "CRITICAL" "CRITICAL" "$NOTE"
                else
                    _layout_row "$LABEL" "Off" "PASS" "PASS" "$NOTE"
                fi
                ;;
            W)
                _layout_row "$LABEL" "$RAW" "INFO" "INFO" "$NOTE"
                ;;
            D)
                # KIND D: 0/disabled = PASS, 1/enabled = WARN
                if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                    _layout_row "$LABEL" "Disabled" "PASS" "PASS" "$NOTE"
                elif [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _layout_row "$LABEL" "Enabled" "WARN" "WARN" "$NOTE"
                else
                    _layout_row "$LABEL" "N/A" "INFO" "INFO" "$NOTE"
                fi
                ;;
            H)
                local WORST="pass"
                local MSGS=()
                IFS=',' read -ra _HKARR <<< "$KEYS"
                local K
                for K in "${_HKARR[@]}"; do
                    local RESULT="${HEALTH[$K]:-skip}"
                    [ -n "${HEALTH_MSG[$K]:-}" ] && MSGS+=("${HEALTH_MSG[$K]}")
                    case "$RESULT" in
                        fail) WORST="fail" ;;
                        warn) [ "$WORST" != "fail" ] && WORST="warn" ;;
                    esac
                done
                local BKIND="INFO"
                case "$WORST" in
                    pass) BKIND="PASS" ;;
                    warn) BKIND="WARN" ;;
                    fail) BKIND="CRITICAL" ;;
                esac
                local JOINED_MSG
                JOINED_MSG="$(IFS='; '; echo "${MSGS[*]}")"
                _layout_row "$LABEL" "" "$BKIND" "$BKIND" "${JOINED_MSG:-$NOTE}"
                ;;
            *)
                if [ -n "$RAW" ]; then
                    _layout_row "$LABEL" "$RAW" "INFO" "INFO" "$NOTE"
                else
                    _layout_row "$LABEL" "N/A" "INFO" "INFO" "$NOTE"
                fi
                ;;
        esac
    done < "$CHECKLIST_FILE"
}

# =============================================================================
# SECTION 10: PDF LOW-LEVEL WRITER
# =============================================================================

_pdf_obj() {
    local NUM="$1"
    local CONTENT="$2"
    PDF_OFFSETS[$NUM]="$(wc -c < "$PDF_OUT_FILE")"
    printf '%s' "$CONTENT" >> "$PDF_OUT_FILE"
}

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
    local i
    for ((i=1; i<=P; i++)); do
        KIDS="${KIDS}$((2+i)) 0 R "
    done
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

# =============================================================================
# SECTION 11: MAIN BUILDER
# =============================================================================

build_pdf() {
    local OUT_PDF="${OUTPUT_PDF:-${PROJECT_ROOT}/output/report.pdf}"
    _PDF_PAGES=()
    _PDF_CUR=""
    _PDF_Y=$PDF_TOP_Y

    _layout_cover
    if [ "${#HEALTH[@]}" -gt 0 ] || [ -n "${DATA[watchdog.memory.status]:-}" ]; then
        _render_health_summary
    fi
    _layout_new_page
    _render_checklist

    _layout_new_page
    _layout_section_header "Collector Status"
    local K
    local FAILED_COLLECTORS=0
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
