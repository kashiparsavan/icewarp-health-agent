#!/bin/bash

###############################################################################
#
# Management Report (lib/management_report.sh)
#
# A short, non-technical report for management/customers: a cover letter
# page plus 2-3 condensed summary pages - no raw data, no per-item notes,
# just a status grid grouped by checklist section.
# Reads from config/checklist.conf.pdf - same source as the full technical report.
#
###############################################################################

MR_PAGE_W=612
MR_PAGE_H=792
MR_MARGIN=40
MR_TOP_Y=752
MR_BOTTOM_Y=44
MR_RIGHT=$((MR_PAGE_W - MR_MARGIN))
MR_CONTENT_W=$((MR_RIGHT - MR_MARGIN))

MR_C_TERRACOTTA="0.72 0.32 0.20"
MR_C_TERRACOTTA_DARK="0.55 0.22 0.14"
MR_C_AMBER="0.87 0.60 0.20"
MR_C_CREAM="0.99 0.96 0.92"
MR_C_CREAM_ROW="0.97 0.92 0.86"
MR_C_BROWN_TEXT="0.30 0.19 0.13"
MR_C_BROWN_SOFT="0.52 0.40 0.33"
MR_C_WHITE="1 1 1"
MR_C_GREEN="0.22 0.55 0.30"
MR_C_RED="0.75 0.24 0.18"
MR_C_GRAY="0.62 0.60 0.57"
MR_C_INFO_BADGE="0.35 0.45 0.58"

_is_num() { [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; }

_mr_escape() {
    local S="$1"
    S="$(printf '%s' "$S" | LC_ALL=C tr -c '\40-\176' '?')"
    S="${S//\\/\\\\}"; S="${S//(/\\(}"; S="${S//)/\\)}"
    printf '%s' "$S"
}

_mr_rect() {
    _MR_CUR="${_MR_CUR}${5} rg
${1} ${2} ${3} ${4} re f
"
}

_mr_text() {
    local ESC; ESC="$(_mr_escape "$3")"
    _MR_CUR="${_MR_CUR}${6} rg
BT /${4} ${5} Tf ${1} ${2} Td (${ESC}) Tj ET
"
}

_mr_text_trunc() {
    local MAXC="$7" TXT="$3"
    [ "${#TXT}" -gt "$MAXC" ] && TXT="${TXT:0:$((MAXC-1))}."
    _mr_text "$1" "$2" "$TXT" "$4" "$5" "$6"
}

_mr_circle() {
    local CX="$1" CY="$2" R="$3" COLOR="$4"
    local K
    K="$(awk -v r="$R" 'BEGIN{printf "%.3f", r*0.5523}')"
    local X0 X1 Y0 Y1
    X0="$(awk -v c="$CX" -v r="$R" 'BEGIN{printf "%.2f", c-r}')"
    X1="$(awk -v c="$CX" -v r="$R" 'BEGIN{printf "%.2f", c+r}')"
    Y0="$(awk -v c="$CY" -v r="$R" 'BEGIN{printf "%.2f", c-r}')"
    Y1="$(awk -v c="$CY" -v r="$R" 'BEGIN{printf "%.2f", c+r}')"
    _MR_CUR="${_MR_CUR}${COLOR} rg
${CX} ${Y1} m
$(awk -v cx="$CX" -v k="$K" -v y1="$Y1" 'BEGIN{printf "%.2f %.2f", cx+k, y1}') $(awk -v x1="$X1" -v cy="$CY" -v k="$K" 'BEGIN{printf "%.2f %.2f", x1, cy+k}') ${X1} ${CY} c
$(awk -v x1="$X1" -v cy="$CY" -v k="$K" 'BEGIN{printf "%.2f %.2f", x1, cy-k}') $(awk -v cx="$CX" -v k="$K" -v y0="$Y0" 'BEGIN{printf "%.2f %.2f", cx+k, y0}') ${CX} ${Y0} c
$(awk -v cx="$CX" -v k="$K" -v y0="$Y0" 'BEGIN{printf "%.2f %.2f", cx-k, y0}') $(awk -v x0="$X0" -v cy="$CY" -v k="$K" 'BEGIN{printf "%.2f %.2f", x0, cy-k}') ${X0} ${CY} c
$(awk -v x0="$X0" -v cy="$CY" -v k="$K" 'BEGIN{printf "%.2f %.2f", x0, cy+k}') $(awk -v cx="$CX" -v k="$K" -v y1="$Y1" 'BEGIN{printf "%.2f %.2f", cx-k, y1}') ${CX} ${Y1} c
f
"
}

_MR_PAGES=()
_MR_CUR=""
_MR_Y=$MR_TOP_Y

_mr_new_page() {
    [ -n "$_MR_CUR" ] && _MR_PAGES+=("$_MR_CUR")
    _MR_CUR=""
    _MR_Y=$MR_TOP_Y
}

_mr_ensure() {
    if [ "$((_MR_Y - $1))" -lt "$MR_BOTTOM_Y" ]; then _mr_new_page; fi
}

_mr_finish() { [ -n "$_MR_CUR" ] && _MR_PAGES+=("$_MR_CUR"); }

_mr_section_header() {
    _mr_ensure 30
    _MR_Y=$((_MR_Y - 4))
    _mr_rect "$MR_MARGIN" "$((_MR_Y - 16))" "$MR_CONTENT_W" 20 "$MR_C_TERRACOTTA"
    _mr_text "$((MR_MARGIN + 8))" "$((_MR_Y - 11))" "$1" "F2" 10.5 "$MR_C_WHITE"
    _MR_Y=$((_MR_Y - 28))
}

_mr_status_style() {
    case "$1" in
        OK) echo "$MR_C_GREEN:✔" ;;
        PASS) echo "$MR_C_GREEN:✔" ;;
        WARN) echo "$MR_C_AMBER:!" ;;
        CRITICAL) echo "$MR_C_RED:X" ;;
        FAIL) echo "$MR_C_RED:X" ;;
        NA) echo "$MR_C_GRAY:-" ;;
        INFO) echo "$MR_C_INFO_BADGE:i" ;;
        *) echo "$MR_C_GRAY:?" ;;
    esac
}

_MR_COL=0
_mr_grid_reset() { _MR_COL=0; }

_mr_grid_item() {
    local LABEL="$1" STATUS="$2"
    local STYLE; STYLE="$(_mr_status_style "$STATUS")"
    local COLOR="${STYLE%%:*}"
    local LETTER="${STYLE#*:}"

    local COL_W=$((MR_CONTENT_W / 2))
    local X=$((MR_MARGIN + (_MR_COL * COL_W)))

    if [ "$_MR_COL" -eq 0 ]; then
        _mr_ensure 20
    fi

    local CY=$((_MR_Y - 7))
    _mr_circle "$((X + 9))" "$CY" 6 "$COLOR"
    _mr_text "$((X + 6))" "$((CY - 3))" "$LETTER" "F2" 6.5 "$MR_C_WHITE"
    _mr_text_trunc "$((X + 22))" "$((_MR_Y - 9))" "$LABEL" "F1" 8.3 "$MR_C_BROWN_TEXT" 46

    if [ "$_MR_COL" -eq 0 ]; then
        _MR_COL=1
    else
        _MR_COL=0
        _MR_Y=$((_MR_Y - 17))
    fi
}

_mr_grid_end_row() {
    if [ "$_MR_COL" -ne 0 ]; then
        _MR_COL=0
        _MR_Y=$((_MR_Y - 17))
    fi
}

_mr_obj() {
    MR_OFFSETS[$1]="$(wc -c < "$MR_OUT_FILE")"
    printf '%s' "$2" >> "$MR_OUT_FILE"
}

_mr_write_file() {
    local OUT_PDF="$1"
    local P="${#_MR_PAGES[@]}"
    [ "$P" -eq 0 ] && { echo "[WARN] management report: nothing to render" >&2; return 1; }

    local F_REG=$((2 + 2*P + 1)) F_BOLD=$((2 + 2*P + 2)) F_OBL=$((2 + 2*P + 3))
    declare -Ag MR_OFFSETS=()
    MR_OUT_FILE="$OUT_PDF"

    : > "$OUT_PDF"
    printf '%%PDF-1.4\n' >> "$OUT_PDF"
    _mr_obj 1 "1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
"
    local KIDS="" i
    for ((i=1; i<=P; i++)); do KIDS="${KIDS}$((2+i)) 0 R "; done
    _mr_obj 2 "2 0 obj
<< /Type /Pages /Kids [ ${KIDS}] /Count ${P} >>
endobj
"
    for ((i=1; i<=P; i++)); do
        local PN=$((2+i)) CN=$((2+P+i))
        local STREAM="${_MR_PAGES[$((i-1))]}"
        local SLEN; SLEN="$(printf '%s' "$STREAM" | wc -c)"
        _mr_obj "$PN" "${PN} 0 obj
<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 ${F_REG} 0 R /F2 ${F_BOLD} 0 R /F3 ${F_OBL} 0 R >> >> /MediaBox [0 0 ${MR_PAGE_W} ${MR_PAGE_H}] /Contents ${CN} 0 R >>
endobj
"
        _mr_obj "$CN" "${CN} 0 obj
<< /Length ${SLEN} >>
stream
${STREAM}
endstream
endobj
"
    done
    _mr_obj "$F_REG" "${F_REG} 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
"
    _mr_obj "$F_BOLD" "${F_BOLD} 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>
endobj
"
    _mr_obj "$F_OBL" "${F_OBL} 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique >>
endobj
"
    local XSTART; XSTART="$(wc -c < "$OUT_PDF")"
    local TOTAL=$((F_OBL + 1))
    {
        printf 'xref\n0 %d\n' "$TOTAL"
        printf '0000000000 65535 f \n'
        local n
        for ((n=1; n<=F_OBL; n++)); do printf '%010d 00000 n \n' "${MR_OFFSETS[$n]}"; done
        printf 'trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n' "$TOTAL" "$XSTART"
    } >> "$OUT_PDF"
    echo "[INFO] Management report written: $OUT_PDF ($(wc -c < "$OUT_PDF") bytes, ${P} page(s))"
}

_days_ago() {
    local date_str="$1"
    [[ -z "$date_str" ]] && echo "999"
    local date_epoch=$(date -d "$date_str" +%s 2>/dev/null)
    [[ -z "$date_epoch" ]] && echo "999"
    echo $(( ( $(date +%s) - date_epoch ) / 86400 ))
}

_validate_intrusion_value() {
    local KEY="$1"
    local VALUE="$2"
    local EXPECTED=""
    case "$KEY" in
        "security.intrusion.block_connections_per_minute.value") EXPECTED="10" ;;
        "security.intrusion.block_unknown_user_count.value") EXPECTED="5" ;;
        "security.intrusion.block_relay_denied_count.value") EXPECTED="5" ;;
        "security.intrusion.block_rset_count.value") EXPECTED="5" ;;
        "security.intrusion.block_spam_score.value") EXPECTED="9.00" ;;
        "security.intrusion.block_failed_logins.value") EXPECTED="5" ;;
        "security.intrusion.block_duration_minutes") EXPECTED="30" ;;
        *) echo "INFO" ;;
    esac
    if [ -z "$VALUE" ]; then
        echo "CRITICAL"
    elif [[ "$VALUE" == "$EXPECTED" ]]; then
        echo "PASS"
    else
        echo "WARN"
    fi
}

_mr_render_checklist() {
    local CHECKLIST_FILE="${PROJECT_ROOT}/config/checklist.conf.pdf"
    local CUR_SECTION=""

    if [ ! -f "$CHECKLIST_FILE" ]; then
        _mr_grid_item "Checklist file not found" "NA"
        return
    fi

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        line=$(echo "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$line" ] && continue

        IFS='~' read -r SECTION LABEL KIND KEYS NOTE <<< "$line"

        if [ "$SECTION" != "$CUR_SECTION" ]; then
            [ -n "$CUR_SECTION" ] && _mr_grid_end_row
            _mr_section_header "$SECTION"
            CUR_SECTION="$SECTION"
            _mr_grid_reset
        fi

        if [[ "$SECTION" == "MySQL Server"* ]] && [ "${DATA[database.scope]:-}" != "remote" ]; then
            _mr_grid_item "$LABEL" "NA"
            continue
        fi

        if [[ "$SECTION" == "Database" ]] && [[ "$LABEL" == MySQL* ]] && [[ "${DATA[mysql.applicable]:-false}" != "true" ]]; then
            _mr_grid_item "$LABEL" "NA"
            continue
        fi

        if [ "$LABEL" = "Database Type" ] && [ "${DATA[database.type]:-}" = "sqlite" ]; then
            _mr_grid_item "$LABEL" "WARN"
            continue
        fi

        if [ "$LABEL" = "Set customers-stat@parsavan.com" ]; then
            local RAW="${DATA[monitor.alert_email]:-}"
            if [[ "$RAW" == *"customers-stat@parsavan.com"* ]] || [[ "$RAW" == *"customers-stat"* ]]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "Check for Certificates" ]; then
            local DAYS_LEFT="${DATA[icewarp.ssl.days_left]:-0}"
            local STATUS="INFO"
            if [[ "$DAYS_LEFT" -gt 90 ]]; then STATUS="PASS"
            elif [[ "$DAYS_LEFT" -gt 30 ]]; then STATUS="WARN"
            else STATUS="CRITICAL"
            fi
            _mr_grid_item "$LABEL" "$STATUS"
            continue
        fi

        if [ "$LABEL" = "Last Backup Date and Time" ]; then
            local BACKUP_TIME="${DATA[icewarp.backup.last_time]:-}"
            local STATUS="NA"
            if [ -n "$BACKUP_TIME" ]; then
                local DAYS=$(_days_ago "$BACKUP_TIME")
                if [ "$DAYS" -lt 2 ]; then STATUS="PASS"
                elif [ "$DAYS" -lt 4 ]; then STATUS="WARN"
                else STATUS="CRITICAL"
                fi
            else
                STATUS="CRITICAL"
            fi
            _mr_grid_item "$LABEL" "$STATUS"
            continue
        fi

        if [ "$LABEL" = "Configure Archive Backup Settings" ]; then
            local RAW="${DATA[archive.backup.active]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "2FA" ]; then
            local RAW="${DATA[security.login.2fa_bypass_enabled]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "WARN"
            else
                _mr_grid_item "$LABEL" "PASS"
            fi
            continue
        fi

        if [ "$LABEL" = "Hide Server Version" ]; then
            local RAW="${DATA[smtp.hide_server_version]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "Block Outgoing Port 9001" ]; then
            local RAW="${DATA[security.port_9001_egress.blocked]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "Remove Old AntiSpam Folders" ]; then
            local STATUS="${DATA[security.cyren_folder.status]:-INFO}"
            case "$STATUS" in
                OK) _mr_grid_item "$LABEL" "PASS" ;;
                WARN) _mr_grid_item "$LABEL" "WARN" ;;
                *) _mr_grid_item "$LABEL" "INFO" ;;
            esac
            continue
        fi

        if [ "$LABEL" = "Disable AntiSpam Live" ]; then
            local RAW="${DATA[security.antispam_live.enabled]:-}"
            if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "WARN"
            fi
            continue
        fi

        if [ "$LABEL" = "Process POP3/IMAP" ]; then
            local RAW="${DATA[security.intrusion.process_pop3_imap]:-0}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "Disable Cloud Features" ]; then
            local RAW="${DATA[icewarp.cloud_api.autoconfigure]:-}"
            if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            elif [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "CRITICAL"
            else
                _mr_grid_item "$LABEL" "NA"
            fi
            continue
        fi

        if [ "$LABEL" = "Disable DIGEST-MD5" ]; then
            local RAW="${DATA[security.digest_md5.enabled]:-}"
            if [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            elif [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "CRITICAL"
            else
                _mr_grid_item "$LABEL" "NA"
            fi
            continue
        fi

        if [ "$LABEL" = "Disable IMAP" ] || [ "$LABEL" = "Disable POP3" ]; then
            local RAW="${DATA[${KEYS}]:-0}"
            if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "PASS"
            fi
            continue
        fi

        if [ "$LABEL" = "Disable VRFY" ]; then
            local RAW="${DATA[smtp.deny_vrfy]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            elif [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _mr_grid_item "$LABEL" "CRITICAL"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "Number of Used Seats / License Max Users" ]; then
            local RAW="${DATA[icewarp.license.used_seats_note]:-}"
            if [ -z "$RAW" ] || [[ "$RAW" == *"not available"* ]]; then
                _mr_grid_item "$LABEL" "WARN"
            else
                _mr_grid_item "$LABEL" "INFO"
            fi
            continue
        fi

        if [ "$LABEL" = "Enable Daytime Clock Synchronization" ]; then
            local RAW="${DATA[icewarp.daytime_clock_sync.enabled]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            elif [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _mr_grid_item "$LABEL" "CRITICAL"
            else
                _mr_grid_item "$LABEL" "WARN"
            fi
            continue
        fi

        # --- Enable System Backup (icewarp.backup.auto_enabled) ---
        if [ "$LABEL" = "Enable System Backup" ]; then
            local RAW="${DATA[icewarp.backup.auto_enabled]:-0}"
            if [ "$RAW" = "1" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        # --- Enable Database Backup (icewarp.database_backup.enabled) ---
        if [ "$LABEL" = "Enable Database Backup" ]; then
            local RAW="${DATA[icewarp.database_backup.enabled]:-0}"
            if [ "$RAW" = "1" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        # --- Maximum Number of Simultaneous Threads ---
        if [ "$LABEL" = "Maximum Number of Simultaneous Threads" ]; then
            local RAW="${DATA[smtp.incoming_queue_threads]:-}"
            local STATUS="INFO"
            if [ -z "$RAW" ]; then
                STATUS="CRITICAL"
            elif [ "$RAW" = "10" ]; then
                STATUS="PASS"
            else
                STATUS="WARN"
            fi
            _mr_grid_item "$LABEL" "$STATUS"
            continue
        fi

        # --- Set Directory Cache Schedule ---
        if [ "$LABEL" = "Set Directory Cache Schedule" ]; then
            local RAW="${DATA[directory_cache.scheduled]:-}"
            if [ "$RAW" = "1" ] || [ "$RAW" = "true" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        # --- Watchdog items ---
        if [ "$LABEL" = "Enable System Watchdog" ]; then
            local CTRL="${DATA[watchdog.control]:-0}"
            if [ "$CTRL" = "1" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "Watchdog - SMTP" ]; then
            local VAL="${DATA[watchdog.smtp]:-0}"
            if [ "$VAL" = "1" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "Watchdog - POP3/IMAP" ]; then
            local VAL="${DATA[watchdog.pop3]:-0}"
            if [ "$VAL" = "1" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "Watchdog - IM/VoIP" ]; then
            local VAL="${DATA[watchdog.im]:-0}"
            if [ "$VAL" = "1" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "Watchdog - GroupWare" ]; then
            local VAL="${DATA[watchdog.gw]:-0}"
            if [ "$VAL" = "1" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "Watchdog Interval" ]; then
            local INTERVAL="${DATA[watchdog.interval_minutes]:-0}"
            local STATUS="INFO"
            if [ "$INTERVAL" -eq 0 ]; then
                STATUS="PASS"
            elif [ "$INTERVAL" -ge 1 ] && [ "$INTERVAL" -le 60 ]; then
                STATUS="PASS"
            elif [ "$INTERVAL" -gt 60 ] && [ "$INTERVAL" -le 1440 ]; then
                STATUS="WARN"
            else
                STATUS="CRITICAL"
            fi
            _mr_grid_item "$LABEL" "$STATUS"
            continue
        fi

        # --- APP OS / Infrastructure items ---
        if [ "$KIND" = "V" ]; then
            case "$LABEL" in
                "Disk (Total GB / Used %)")
                    local USED_PERCENT="${DATA[storage.root_fs.used_percent]:-0}"
                    local STATUS="INFO"
                    if _is_num "$USED_PERCENT"; then
                        if [ "$USED_PERCENT" -ge 95 ]; then STATUS="CRITICAL"
                        elif [ "$USED_PERCENT" -ge 80 ]; then STATUS="WARN"
                        else STATUS="PASS"
                        fi
                    fi
                    _mr_grid_item "$LABEL" "$STATUS"
                    continue
                    ;;
                "CPU Usage")
                    local LOAD15="${DATA[os.cpu.load15]:-0}"
                    local CORES="${DATA[os.cpu.count]:-1}"
                    local CPU_PERCENT=0
                    local STATUS="INFO"
                    if _is_num "$LOAD15" && _is_num "$CORES" && [ "$CORES" -gt 0 ]; then
                        CPU_PERCENT=$(awk -v l="$LOAD15" -v c="$CORES" 'BEGIN{printf "%.2f", (l/c)*100}')
                        if awk -v cpu="$CPU_PERCENT" -v lim=95 'BEGIN{exit !(cpu > lim)}'; then STATUS="CRITICAL"
                        elif awk -v cpu="$CPU_PERCENT" -v lim=50 'BEGIN{exit !(cpu > lim)}'; then STATUS="WARN"
                        else STATUS="PASS"
                        fi
                    fi
                    _mr_grid_item "$LABEL" "$STATUS"
                    continue
                    ;;
                "RAM (Total KB / Available KB)")
                    local TOTAL_KB="${DATA[os.memory.total_kb]:-0}"
                    local AVAIL_KB="${DATA[os.memory.available_kb]:-0}"
                    local USED_PERCENT=0
                    local STATUS="INFO"
                    if _is_num "$TOTAL_KB" && _is_num "$AVAIL_KB" && [ "$TOTAL_KB" -gt 0 ]; then
                        USED_PERCENT=$(awk -v t="$TOTAL_KB" -v a="$AVAIL_KB" 'BEGIN{printf "%.2f", ((t-a)/t)*100}')
                        if awk -v used="$USED_PERCENT" -v lim=90 'BEGIN{exit !(used > lim)}'; then STATUS="CRITICAL"
                        elif awk -v used="$USED_PERCENT" -v lim=40 'BEGIN{exit !(used > lim)}'; then STATUS="WARN"
                        else STATUS="PASS"
                        fi
                    fi
                    _mr_grid_item "$LABEL" "$STATUS"
                    continue
                    ;;
                "APP OS Last Update")
                    local LAST_UPDATE="${DATA[os.last_update_date]:-}"
                    local STATUS="INFO"
                    if [ -n "$LAST_UPDATE" ] && [ "$LAST_UPDATE" != "N/A" ] && [ "$LAST_UPDATE" != "null" ]; then
                        local DAYS=$(_days_ago "$LAST_UPDATE")
                        if [ "$DAYS" -le 7 ]; then STATUS="PASS"
                        elif [ "$DAYS" -le 30 ]; then STATUS="WARN"
                        else STATUS="CRITICAL"
                        fi
                    fi
                    _mr_grid_item "$LABEL" "$STATUS"
                    continue
                    ;;
                "Swap Usage (7 days)")
                    local STATUS="${DATA[system.swap.status]:-INFO}"
                    case "$STATUS" in
                        PASS) _mr_grid_item "$LABEL" "PASS" ;;
                        CRITICAL) _mr_grid_item "$LABEL" "CRITICAL" ;;
                        *) _mr_grid_item "$LABEL" "INFO" ;;
                    esac
                    continue
                    ;;
            esac
            _mr_grid_item "$LABEL" "$([ -n "${DATA[$KEYS]:-}" ] && echo "INFO" || echo "NA")"
            continue
        fi

        # --- Intrusion Prevention validation ---
        if [ "$KIND" = "V" ] && [[ "$KEYS" == security.intrusion.*.value* || "$KEYS" == "security.intrusion.block_duration_minutes" ]]; then
            local RAW="${DATA[$KEYS]:-}"
            local STATUS="$(_validate_intrusion_value "$KEYS" "$RAW")"
            _mr_grid_item "$LABEL" "$STATUS"
            continue
        fi

        if [ "$KIND" = "T" ]; then
            local RAW="${DATA[$KEYS]:-}"
            local EXPECTED="$NOTE"
            if [ "$RAW" = "$EXPECTED" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "WARN"
            fi
            continue
        fi

        local RAW="${DATA[$KEYS]:-}"
        case "$KIND" in
            F)
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _mr_grid_item "$LABEL" "PASS"
                elif [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                    _mr_grid_item "$LABEL" "CRITICAL"
                else
                    _mr_grid_item "$LABEL" "NA"
                fi
                ;;
            B)
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _mr_grid_item "$LABEL" "PASS"
                else
                    _mr_grid_item "$LABEL" "CRITICAL"
                fi
                ;;
            R)
                if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                    _mr_grid_item "$LABEL" "PASS"
                elif [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _mr_grid_item "$LABEL" "CRITICAL"
                else
                    _mr_grid_item "$LABEL" "NA"
                fi
                ;;
            V)
                if [ "$LABEL" = "APP OS Last Update" ]; then
                    local LAST_UPDATE="${DATA[os.last_update_date]:-}"
                    local STATUS="INFO"
                    if [ -n "$LAST_UPDATE" ] && [ "$LAST_UPDATE" != "N/A" ] && [ "$LAST_UPDATE" != "null" ]; then
                        local DAYS=$(_days_ago "$LAST_UPDATE")
                        if [ "$DAYS" -le 7 ]; then STATUS="PASS"
                        elif [ "$DAYS" -le 30 ]; then STATUS="WARN"
                        else STATUS="CRITICAL"
                        fi
                    fi
                    _mr_grid_item "$LABEL" "$STATUS"
                else
                    _mr_grid_item "$LABEL" "$([ -n "$RAW" ] && echo "INFO" || echo "NA")"
                fi
                ;;
            L)
                if [ "${DATA[database.type]:-}" = "mysql" ] && [ "${DATA[database.scope]:-}" = "local" ]; then
                    _mr_grid_item "$LABEL" "$([ -n "$RAW" ] && echo "INFO" || echo "NA")"
                else
                    _mr_grid_item "$LABEL" "NA"
                fi
                ;;
            P)
                if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]] || [ -z "$RAW" ]; then
                    _mr_grid_item "$LABEL" "PASS"
                else
                    _mr_grid_item "$LABEL" "CRITICAL"
                fi
                ;;
            Z)
                if [ "$RAW" = "0" ]; then
                    _mr_grid_item "$LABEL" "WARN"
                elif [ -n "$RAW" ]; then
                    _mr_grid_item "$LABEL" "INFO"
                else
                    _mr_grid_item "$LABEL" "NA"
                fi
                ;;
            M)
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _mr_grid_item "$LABEL" "WARN"
                else
                    _mr_grid_item "$LABEL" "PASS"
                fi
                ;;
            G)
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _mr_grid_item "$LABEL" "PASS"
                else
                    _mr_grid_item "$LABEL" "CRITICAL"
                fi
                ;;
            D)
                ;;
            H)
                local WORST="PASS" K RESULT
                IFS=',' read -ra _HK <<< "$KEYS"
                for K in "${_HK[@]}"; do
                    RESULT="${HEALTH[$K]:-skip}"
                    [ "$RESULT" = "fail" ] && WORST="CRITICAL"
                    [ "$RESULT" = "warn" ] && [ "$WORST" != "CRITICAL" ] && WORST="WARN"
                done
                _mr_grid_item "$LABEL" "$WORST"
                ;;
            *)
                if [ -n "$RAW" ]; then
                    _mr_grid_item "$LABEL" "INFO"
                else
                    _mr_grid_item "$LABEL" "NA"
                fi
                ;;
        esac
    done < "$CHECKLIST_FILE"
    _mr_grid_end_row
}

_mr_cover_letter() {
    local HOST="${DATA[agent.hostname]:-unknown}"
    local GEN="${DATA[agent.time]:-unknown}"
    local COMPANY="${DATA[general.company]:-Unknown Host}"
    local TECHNICIAN="${DATA[general.technician]:-Not Specified}"
    local OVERALL="${DATA[health.summary.overall]:-n/a}"
    local FAILED="${DATA[health.summary.failed]:-0}"
    local WARNINGS="${DATA[health.summary.warnings]:-0}"
    local CHECKED="${DATA[health.summary.total_checks]:-0}"

    _mr_rect 0 0 "$MR_PAGE_W" "$MR_PAGE_H" "$MR_C_CREAM"
    _mr_rect 0 700 "$MR_PAGE_W" 92 "$MR_C_TERRACOTTA_DARK"
    _mr_rect 0 692 "$MR_PAGE_W" 8 "$MR_C_AMBER"
    _mr_text "$MR_MARGIN" 750 "IceWarp Health Check Report" "F2" 21 "$MR_C_WHITE"
    _mr_text "$MR_MARGIN" 726 "Prepared for ${COMPANY}" "F3" 12 "$MR_C_WHITE"
    _mr_text "$MR_MARGIN" 708 "Technician: ${TECHNICIAN}" "F1" 9.5 "$MR_C_WHITE"

    _MR_Y=650
    _mr_text "$MR_MARGIN" "$_MR_Y" "$(date -d "$GEN" '+%B %d, %Y' 2>/dev/null || echo "$GEN")" "F1" 10 "$MR_C_BROWN_SOFT"
    _MR_Y=$((_MR_Y - 30))

    local -a PARA=(
        "This report summarizes the results of an automated health and security review"
        "carried out on your IceWarp mail server (${HOST}). The review covers mail delivery"
        "configuration, security hardening, backup and monitoring status, and certificate"
        "validity, evaluated against our standard IceWarp deployment checklist."
        ""
        "Overall, ${CHECKED} checks were carried out. ${FAILED} required attention and ${WARNINGS} are"
        "flagged as warnings worth reviewing; the rest are configured correctly."
        ""
        "The following pages summarize the results by category. A green mark means the"
        "item is configured correctly; amber flags something worth reviewing; red items"
        "need attention. A full technical report with detailed findings is available on"
        "request."
    )
    local LINE
    for LINE in "${PARA[@]}"; do
        _mr_text "$MR_MARGIN" "$_MR_Y" "$LINE" "F1" 10.5 "$MR_C_BROWN_TEXT"
        _MR_Y=$((_MR_Y - 17))
    done

    _MR_Y=$((_MR_Y - 20))
    local BANNER_COLOR="$MR_C_GREEN"
    [ "$OVERALL" = "warn" ] && BANNER_COLOR="$MR_C_AMBER"
    [ "$OVERALL" = "fail" ] && BANNER_COLOR="$MR_C_RED"
    _mr_rect "$MR_MARGIN" "$((_MR_Y - 46))" "$MR_CONTENT_W" 46 "$BANNER_COLOR"
    _mr_text "$((MR_MARGIN + 16))" "$((_MR_Y - 20))" "Overall Status: $(echo "$OVERALL" | tr '[:lower:]' '[:upper:]')" "F2" 15 "$MR_C_WHITE"
    _mr_text "$((MR_MARGIN + 16))" "$((_MR_Y - 37))" "${CHECKED} checks  -  ${FAILED} need attention  -  ${WARNINGS} warnings" "F1" 9.5 "$MR_C_WHITE"
    _MR_Y=$((_MR_Y - 70))

    _mr_text "$MR_MARGIN" "$_MR_Y" "Legend:" "F2" 8.5 "$MR_C_BROWN_TEXT"
    local LX=$((MR_MARGIN + 46))
    local LY="$_MR_Y"
    local ITEMS=("PASS:Configured correctly" "WARN:Needs review" "CRITICAL:Needs attention" "NA:Not applicable" "INFO:Informational value")
    local IT
    for IT in "${ITEMS[@]}"; do
        local ST="${IT%%:*}" LBL="${IT#*:}"
        local ITEM_W=$((18 + 6*${#LBL} + 16))
        if [ "$((LX + ITEM_W))" -gt "$MR_RIGHT" ]; then
            LX=$((MR_MARGIN + 46))
            LY=$((LY - 18))
        fi
        local STYLE; STYLE="$(_mr_status_style "$ST")"
        _mr_circle "$((LX + 6))" "$((LY + 3))" 6 "${STYLE%%:*}"
        _mr_text "$((LX + 6 - 3))" "$LY" "${STYLE#*:}" "F2" 6.5 "$MR_C_WHITE"
        _mr_text "$((LX + 18))" "$LY" "$LBL" "F1" 8 "$MR_C_BROWN_TEXT"
        LX=$((LX + ITEM_W))
    done
    _MR_Y="$LY"

    _mr_new_page
}

build_management_pdf() {
    local OUT_PDF="${OUTPUT_MANAGEMENT_PDF:-${PROJECT_ROOT}/output/management_report.pdf}"
    _MR_PAGES=(); _MR_CUR=""; _MR_Y=$MR_TOP_Y

    _mr_cover_letter
    _mr_render_checklist

    _mr_finish
    _mr_write_file "$OUT_PDF"
}
