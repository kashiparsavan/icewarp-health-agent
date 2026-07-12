#!/bin/bash

###############################################################################
#
# PDF Report Writer (M5) - v2, designed report
#
# Still dependency-free (bash + printf + wc only - no python/wkhtmltopdf on
# the production mail server), but now draws a real designed report instead
# of a monospace data dump: a cover page, colored section banners, and
# colored status badges per checklist item - using PDF's native color and
# rectangle drawing operators, which cost nothing extra to support.
#
###############################################################################

PDF_PAGE_W=612
PDF_PAGE_H=792
PDF_MARGIN=36
PDF_TOP_Y=756
PDF_BOTTOM_Y=44
PDF_CONTENT_RIGHT=$((PDF_PAGE_W - PDF_MARGIN))
PDF_CONTENT_W=$((PDF_CONTENT_RIGHT - PDF_MARGIN))

# Palette (0-1 RGB floats, as PDF expects)
PDF_C_NAVY="0.102 0.235 0.369"
PDF_C_NAVY_LIGHT="0.925 0.941 0.957"
PDF_C_WHITE="1 1 1"
PDF_C_TEXT="0.15 0.17 0.2"
PDF_C_GRAY="0.5 0.53 0.56"
PDF_C_GRAY_LIGHT="0.955 0.96 0.965"
PDF_C_GREEN="0.118 0.518 0.286"
PDF_C_RED="0.753 0.224 0.169"
PDF_C_AMBER="0.83 0.53 0.06"
PDF_C_BLUEGRAY="0.30 0.42 0.55"

_pdf_escape() {
    local S="$1"
    S="$(printf '%s' "$S" | LC_ALL=C tr -c '\40-\176' '?')"
    S="${S//\\/\\\\}"
    S="${S//(/\\(}"
    S="${S//)/\\)}"
    printf '%s' "$S"
}

# --- low-level drawing primitives, append to $_PDF_CUR --------------------

_pdf_rect() {
    # x y w h "r g b"
    _PDF_CUR="${_PDF_CUR}${5} rg
${1} ${2} ${3} ${4} re f
"
}

_pdf_text() {
    # x y text font size "r g b"
    local ESC
    ESC="$(_pdf_escape "$3")"
    _PDF_CUR="${_PDF_CUR}${6} rg
BT /${4} ${5} Tf ${1} ${2} Td (${ESC}) Tj ET
"
}

_pdf_text_trunc() {
    # like _pdf_text but truncates to a max character count first
    local MAXCHARS="$7"
    local TXT="$3"
    if [ "${#TXT}" -gt "$MAXCHARS" ]; then
        TXT="${TXT:0:$((MAXCHARS-1))}."
    fi
    _pdf_text "$1" "$2" "$TXT" "$4" "$5" "$6"
}

# --- page/layout engine -----------------------------------------------

_PDF_PAGES=()
_PDF_CUR=""
_PDF_Y=$PDF_TOP_Y

_layout_new_page() {
    if [ -n "$_PDF_CUR" ]; then
        _PDF_PAGES+=("$_PDF_CUR")
    fi
    _PDF_CUR=""
    _PDF_Y=$PDF_TOP_Y
}

_layout_ensure() {
    local NEEDED="$1"
    if [ "$((_PDF_Y - NEEDED))" -lt "$PDF_BOTTOM_Y" ]; then
        _layout_new_page
    fi
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

# badge color name -> "r g b" + label text
_badge_color() {
    case "$1" in
        ON|PASS) echo "$PDF_C_GREEN" ;;
        OFF) echo "$PDF_C_GRAY" ;;
        FAIL) echo "$PDF_C_RED" ;;
        WARN|TBD) echo "$PDF_C_AMBER" ;;
        INFO) echo "$PDF_C_BLUEGRAY" ;;
        *) echo "$PDF_C_GRAY" ;;
    esac
}

_layout_row_index=0

_layout_row() {
    # label, value, badge_kind (ON/OFF/TBD/INFO/PASS/WARN/FAIL), badge_text, note(optional)
    local LABEL="$1" VALUE="$2" BKIND="$3" BTEXT="$4" NOTE="${5:-}"
    local ROW_H=16
    [ -n "$NOTE" ] && ROW_H=27

    _layout_ensure "$ROW_H"

    local BG="$PDF_C_WHITE"
    if [ $(( _layout_row_index % 2 )) -eq 1 ]; then BG="$PDF_C_GRAY_LIGHT"; fi
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

    if [ -n "$NOTE" ]; then
        _pdf_text_trunc "$((PDF_MARGIN + 8))" "$((TEXT_Y - 11))" "note: ${NOTE}" "F3" 7.5 "$PDF_C_GRAY" 100
    fi

    _PDF_Y=$((_PDF_Y - ROW_H))
}

_layout_plain_line() {
    local TEXT="$1"
    _layout_ensure 12
    _pdf_text_trunc "$PDF_MARGIN" "$_PDF_Y" "$TEXT" "F1" 8.5 "$PDF_C_TEXT" 110
    _PDF_Y=$((_PDF_Y - 12))
}

_layout_spacer() {
    _PDF_Y=$((_PDF_Y - ${1:-8}))
}

# --- cover page ---------------------------------------------------------

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
        "Company Name|_______________________"
        "Technician|_______________________"
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
    local LBLS=("ON=enabled" "OFF=disabled" "TBD=not collected yet" "INFO=informational value")
    local LKINDS=("ON" "OFF" "TBD" "INFO")
    local I
    for I in 0 1 2 3; do
        local BC
        BC="$(_badge_color "${LKINDS[$I]}")"
        _pdf_rect "$LX" "$((_PDF_Y - 3))" 26 11 "$BC"
        _pdf_text "$((LX + 30))" "$_PDF_Y" "${LBLS[$I]}" "F1" 8 "$PDF_C_TEXT"
        LX=$((LX + 30 + 6*${#LBLS[$I]} + 14))
    done
    _PDF_Y=$((_PDF_Y - 20))
}

###############################################################################
# Checklist v1.12 definition (unchanged content, same as v1 - see notes)
###############################################################################

_CL_ITEMS='DNS & Mail Flow Verification~Check PTR~B~dns.ptr.checked~
DNS & Mail Flow Verification~Check SPF~B~dns.spf.checked~
DNS & Mail Flow Verification~Check DKIM~B~dns.dkim.checked~
DNS & Mail Flow Verification~Check DMARC~B~dns.dmarc.checked~
DNS & Mail Flow Verification~Check TLS and Start TLS~B~smtp.starttls_live_test~
DNS & Mail Flow Verification~Check DNS Server~V~dns.configured_server~
DNS & Mail Flow Verification~Test DNS Lookup~B~dns.lookup_test.ok~
Logging~Enable Logging - Authentication~V~logging.auth_log_level~
Logging~Enable Logging - Maintenance~V~logging.maintenance_log_level~
Logging~Enable MailFlow Log~V~logging.mailqueue.level~
Logging~Enable SQL Failed Logs~V~logging.sql_log_type~
Backup, Watchdog and Monitoring~Enable System Backup~B~icewarp.backup.auto_enabled~
Backup, Watchdog and Monitoring~Enable Database Backup~X~~no collector yet, tool.help property not confirmed
Backup, Watchdog and Monitoring~Configure Archive Backup Settings~B~archive.backup.active~
Backup, Watchdog and Monitoring~Enable System Watchdog~V~watchdog.smtp,watchdog.pop3,watchdog.im,watchdog.gw,watchdog.control~
Backup, Watchdog and Monitoring~Enable System Monitor (Mem/Disk/CPU)~V~monitor.memory.alert_below_gb,monitor.disk.alert_below_mb,monitor.cpu.threshold_percent~fails if threshold exceeds actual server capacity, see Health Summary
Backup, Watchdog and Monitoring~Last Backup Date and Time~V~icewarp.backup.last_time~
Storage, Certificates and Services~Check for Storage Locations~V~icewarp.path.mail~
Storage, Certificates and Services~Check for Certificates~V~icewarp.ssl.cert_path~expiration date not returned on this server, needs verification
Storage, Certificates and Services~RBL Valli Check~B~security.dnsbl.use~unclear if this means a spam-score threshold value, needs confirming
Storage, Certificates and Services~Enable Full Text Search Services~V~fulltext.enabled~value is the service endpoint URL when active, empty when off
Storage, Certificates and Services~Reject if SMTP AUTH Different from Sender~B~smtp.reject_auth_sender_mismatch~
Storage, Certificates and Services~2FA~B~security.login.2fa_bypass_enabled~this is the BYPASS flag, not whether 2FA is required - needs correct property confirmed
Storage, Certificates and Services~Archive Active~B~archive.active~
SMTP Delivery Settings~Max Message Size (MB)~V~smtp.max_message_size.mb~
SMTP Delivery Settings~Delivery Reports~X~~no collector yet
SMTP Delivery Settings~Use TLS/SSL (Secured Delivery)~B~smtp.use_tls_ssl~
SMTP Delivery Settings~Process Incoming Messages in MDA Queue~B~smtp.use_incoming_queue~
SMTP Delivery Settings~Use MDA Queue for Internal Message Delivery~B~smtp.mda_internal_delivery~may be the same underlying setting as the item above, needs confirming
SMTP Delivery Settings~Maximum Number of Simultaneous Threads~V~smtp.thread_cache~
SMTP Delivery Settings~Hide IP Address from Received for All Messages~B~smtp.hide_ip~
SMTP Delivery Settings~Hide Server Version~B~smtp.hide_server_version~
SMTP Protocol Hardening~Require HELO/EHLO~B~smtp.require_helo_ehlo~
SMTP Protocol Hardening~Add Return-Path to All Messages~B~smtp.add_return_path~
SMTP Protocol Hardening~Dedupe Email Messages~B~smtp.dedupe~
SMTP Protocol Hardening~Relay Only if Originators Domain is Local~B~smtp.relay.local_domain_only~
SMTP Protocol Hardening~Process SMTP~B~security.intrusion.process_smtp~ambiguous, a separate watchdog-level flag may also apply - needs confirming
SMTP Protocol Hardening~Process POP3/IMAP~B~security.intrusion.process_pop3_imap~ambiguous, see note above
SMTP Protocol Hardening~Add rDNS Result to Received for All Messages~B~smtp.rdns_in_received~
SMTP Protocol Hardening~Set Directory Cache Schedule~V~directory_cache.schedule_raw~format not decoded yet
SMTP Protocol Hardening~Change Admin URL~V~admin.url~raw value only, not compared against the default
Intrusion Prevention - Block Rules~Block IP - Connections in 1 Minute~V~security.intrusion.block_connections_per_minute.value~
Intrusion Prevention - Block Rules~Block IP - Unknown User Delivery Count~V~security.intrusion.block_unknown_user_count.value~
Intrusion Prevention - Block Rules~Block IP - Denied for Relaying Too Often~V~security.intrusion.block_relay_denied_count.value~
Intrusion Prevention - Block Rules~Block IP - Exceeds RSET Session Count~V~security.intrusion.block_rset_count.value~
Intrusion Prevention - Block Rules~Block IP - Message Spam Score~V~security.intrusion.block_spam_score.value~
Intrusion Prevention - Block Rules~Block IP - Listed on DNSBL~B~security.intrusion.block_dnsbl_listed.enabled~
Intrusion Prevention - Block Rules~Block IP - Exceeds Failed Login Attempts~V~security.intrusion.block_failed_logins.value~
Intrusion Prevention - Block Rules~Amount of Time IP is Blocked (minutes)~V~security.intrusion.block_duration_minutes~
Intrusion Prevention - Block Rules~Refuse Blocked IP Address~B~security.intrusion.refuse_blocked_ip~underlying source property is itself flagged unverified
Intrusion Prevention - Block Rules~Close Blocked Connection~B~security.intrusion.close_blocked_connection~
Intrusion Prevention - Block Rules~Close All Other Connections from Blocked IP~B~security.intrusion.close_all_other_connections~
Intrusion Prevention - Block Rules~Cross Session Processing~B~security.intrusion.cross_session_processing~
Rejection Rules and Access~Use DNSBL~B~security.dnsbl.use~
Rejection Rules and Access~Close Connections for DNSBL Sessions~B~security.dnsbl.close_sessions~
Rejection Rules and Access~Use IP Reputation~B~security.ip_reputation.use~
Rejection Rules and Access~Reject if Originators IP has no rDNS~B~security.reject_no_rdns~
Rejection Rules and Access~Reject if Originators Domain Does Not Exist~B~security.reject_domain_no_mx~mapped to no-MX-record as a proxy, needs confirming
Rejection Rules and Access~Reject if Originators Domain is Local and Not Authorized~X~~no collector yet
Rejection Rules and Access~Set customers-stat@parsavan.com~X~~unclear if distinct from monitor.alert_email, needs correct property name
Rejection Rules and Access~Disable AntiSpam Live~X~~no collector yet
Rejection Rules and Access~Remove Old AntiSpam Folders~X~~cleanup action, may not fit the collector pattern
Rejection Rules and Access~Password Policy Min Length~V~security.password_policy.min_length~
Rejection Rules and Access~Set Admin Email~V~monitor.alert_email~
Rejection Rules and Access~Change Admin Port~B~admin.port_changed_from_default~
Rejection Rules and Access~Block Outgoing Port 9001~X~~no collector yet
Archive Settings~Archive to Directory~V~icewarp.archive.default~
Archive Settings~Number of Used Seats / License Max Users~X~~no collector yet
Archive Settings~Integrate Archive with IMAP Folder~B~archive.integrate_with_imap~
Archive Settings~Do Not Archive Spam~B~archive.do_not_archive_spam~
Archive Settings~Enable Daytime Clock Synchronization~B~icewarp.daytime_clock_sync.enabled~
Protocol and Access Hardening~Disable VRFY~B~smtp.deny_vrfy~
Protocol and Access Hardening~Disable DIGEST-MD5~B~security.digest_md5.enabled~
Protocol and Access Hardening~Session Timeout~X~~no collector yet
Protocol and Access Hardening~Enable SSL/TLS~B~smtp.use_tls_ssl~may be a broader admin/IMAP/POP3 toggle distinct from the SMTP item above, needs confirming
Protocol and Access Hardening~Disable Cloud Features~X~~no collector yet
Protocol and Access Hardening~Disable IMAP/POP3~V~service.imap.active,service.pop3.active~
APP OS / Infrastructure~APP OS Version~V~general.os.pretty~
APP OS / Infrastructure~Disk (Total GB / Used %)~V~storage.root_fs.total_gb,storage.root_fs.used_percent~
APP OS / Infrastructure~CPU Usage~V~os.cpu.load1~1-min load average collected, not literal CPU percent - needs confirming if acceptable
APP OS / Infrastructure~RAM (Total KB / Available KB)~V~os.memory.total_kb,os.memory.available_kb~
APP OS / Infrastructure~APP OS Last Update~X~~no collector yet
APP OS / Infrastructure~MySQL IP Address~V~database.host~only populated when a remote MySQL server is detected
APP OS / Infrastructure~Repository Access~X~~no collector yet
APP OS / Infrastructure~Time Sync~V~icewarp.daytime_clock_sync.enabled~this is IceWarps own daytime sync, not OS-level NTP/chrony - needs confirming
MySQL Server (Remote DB)~MySQL Server Section~X~~entire block only applies when database.mysql_server_section_applicable=true; not built yet'

_cl_bool_kind() {
    case "${1:-}" in
        1|true|TRUE|True) echo "ON:ENABLED" ;;
        0|false|FALSE|False) echo "OFF:DISABLED" ;;
        "") echo "TBD:N/A" ;;
        *) echo "INFO:$1" ;;
    esac
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

_render_checklist() {
    local CUR_SECTION=""
    local SECTION LABEL KIND KEYS NOTE
    while IFS='~' read -r SECTION LABEL KIND KEYS NOTE; do
        [ -z "$SECTION" ] && continue
        if [ "$SECTION" != "$CUR_SECTION" ]; then
            _layout_section_header "$SECTION"
            CUR_SECTION="$SECTION"
            _layout_row_index=0
        fi
        case "$KIND" in
            B)
                local RESULT
                RESULT="$(_cl_bool_kind "${DATA[$KEYS]:-}")"
                _layout_row "$LABEL" "${RESULT#*:}" "${RESULT%%:*}" "${RESULT%%:*}" "$NOTE"
                ;;
            V)
                local VAL
                VAL="$(_cl_value_render "$KEYS")"
                _layout_row "$LABEL" "$VAL" "INFO" "INFO" "$NOTE"
                ;;
            X)
                _layout_row "$LABEL" "not collected" "TBD" "TBD" "$NOTE"
                ;;
        esac
    done <<< "$_CL_ITEMS"
}

_render_health_summary() {
    _layout_section_header "Health Summary"
    _layout_row_index=0
    local K
    for K in $(printf '%s\n' "${!HEALTH[@]}" | sort); do
        local RESULT="${HEALTH[$K]}"
        local BKIND
        case "$RESULT" in
            pass) BKIND="PASS" ;;
            warn) BKIND="WARN" ;;
            fail) BKIND="FAIL" ;;
            *) BKIND="INFO" ;;
        esac
        _layout_row "$K" "" "$BKIND" "$(echo "$RESULT" | tr '[:lower:]' '[:upper:]')" "${HEALTH_MSG[$K]:-}"
    done
}

###############################################################################
# Low-level PDF object writer (3 fonts: F1 regular, F2 bold, F3 oblique)
###############################################################################

_pdf_obj() {
    local NUM="$1"; shift
    PDF_OFFSETS[$NUM]="$(wc -c < "$PDF_OUT_FILE")"
    printf '%s' "$1" >> "$PDF_OUT_FILE"
}

_pdf_write_file() {
    local OUT_PDF="$1"
    local P="${#_PDF_PAGES[@]}"

    if [ "$P" -eq 0 ]; then
        echo "[WARN] build_pdf: nothing to render, skipping PDF output" >&2
        return 1
    fi

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
    local KIDS="" i
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
        local STREAM_LEN
        STREAM_LEN="$(printf '%s' "$STREAM" | wc -c)"

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

    local XREF_START
    XREF_START="$(wc -c < "$OUT_PDF")"
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

###############################################################################
# Entry point
###############################################################################

build_pdf() {
    local OUT_PDF="${OUTPUT_PDF:-${PROJECT_ROOT}/output/report.pdf}"

    _PDF_PAGES=()
    _PDF_CUR=""
    _PDF_Y=$PDF_TOP_Y

    _layout_cover
    if [ "${#HEALTH[@]}" -gt 0 ]; then
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
        _layout_row "$K" "${STATUS_MSG[$K]:-}" "TBD" "${STATUS[$K]}" ""
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
