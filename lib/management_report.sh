#!/bin/bash

###############################################################################
#
# Management Report (lib/management_report.sh)
#
# A short, non-technical report for management/customers: a cover letter
# page plus 2-3 condensed summary pages - no raw data, no per-item notes,
# just a warm-colored status grid grouped by checklist section. Separate
# from the full technical report (lib/pdf.sh / report.pdf); this writes
# output/management_report.pdf. Still pure bash + printf - zero dependencies.
#
###############################################################################

MR_PAGE_W=612
MR_PAGE_H=792
MR_MARGIN=40
MR_TOP_Y=752
MR_BOTTOM_Y=44
MR_RIGHT=$((MR_PAGE_W - MR_MARGIN))
MR_CONTENT_W=$((MR_RIGHT - MR_MARGIN))

# Warm palette
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

# Bezier-approximated filled circle, centered at cx,cy, radius r, color "r g b"
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

# status -> (bg color, letter)
_mr_status_style() {
    case "$1" in
        OK) echo "$MR_C_GREEN:OK" ;;
        WARN) echo "$MR_C_AMBER:!" ;;
        FAIL) echo "$MR_C_RED:X" ;;
        NA) echo "$MR_C_GRAY:-" ;;
        INFO) echo "$MR_C_INFO_BADGE:i" ;;
        *) echo "$MR_C_GRAY:?" ;;
    esac
}

# Compact 2-column grid: circle + label, no notes/values.
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

###############################################################################
# Low-level PDF writer (3 fonts, same technique as the technical report)
###############################################################################

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

###############################################################################
# Checklist definition (condensed - status only, no values/notes shown)
# SECTION~LABEL~KIND~KEYS   (KIND: B=bool  H=health-ref  X=not collected)
###############################################################################

_MR_ITEMS='DNS & Mail Flow Verification~Check PTR~B~dns.ptr.matches_hostname
DNS & Mail Flow Verification~Check SPF~B~dns.spf.found
DNS & Mail Flow Verification~Check DKIM~B~dns.dkim.found
DNS & Mail Flow Verification~Check DMARC~B~dns.dmarc.found
DNS & Mail Flow Verification~Check TLS and Start TLS~B~smtp.starttls_live_test
DNS & Mail Flow Verification~Check DNS Server~V~dns.configured_server
DNS & Mail Flow Verification~Test DNS Lookup~B~dns.lookup_test.ok
Logging~Enable Logging - Authentication~B~logging.auth_log_level
Logging~Enable Logging - Maintenance~B~logging.maintenance_log_level
Logging~Enable MailFlow Log~B~logging.mailqueue.level
Logging~Enable SQL Failed Logs~B~logging.sql_log_type
Backup, Watchdog and Monitoring~Enable System Backup~B~icewarp.backup.auto_enabled
Backup, Watchdog and Monitoring~Last Backup Date and Time~V~icewarp.backup.last_time
Backup, Watchdog and Monitoring~Enable Database Backup~B~icewarp.database_backup.enabled
Backup, Watchdog and Monitoring~Configure Archive Backup Settings~B~archive.backup.active
Backup, Watchdog and Monitoring~Enable System Watchdog~B~watchdog.control
Backup, Watchdog and Monitoring~Enable System Monitor (Mem/Disk/CPU)~H~memory,cpu,disk.overall
Storage, Certificates and Services~Check for Storage Locations~V~icewarp.path.mail
Storage, Certificates and Services~Check for Certificates~V~icewarp.ssl.expiration
Storage, Certificates and Services~RBL Valli Check (is our IP blacklisted)~R~security.rbl_self_check.listed
Storage, Certificates and Services~Enable Full Text Search Services~V~fulltext.enabled
Storage, Certificates and Services~Reject if SMTP AUTH Different from Sender~B~smtp.reject_auth_sender_mismatch
Storage, Certificates and Services~2FA~R~security.login.2fa_bypass_enabled
Storage, Certificates and Services~Archive Active~B~archive.active
SMTP Delivery Settings~Max Message Size (MB)~V~smtp.max_message_size.mb
SMTP Delivery Settings~Delivery Reports~B~smtp.delivery_reports_enabled
SMTP Delivery Settings~Use TLS/SSL (Secured Delivery)~B~smtp.use_tls_ssl
SMTP Delivery Settings~Process Incoming Messages in MDA Queue~B~smtp.use_incoming_queue
SMTP Delivery Settings~Use MDA Queue for Internal Message Delivery~B~smtp.mda_internal_delivery
SMTP Delivery Settings~Maximum Number of Simultaneous Threads~V~smtp.thread_cache
SMTP Delivery Settings~Hide IP Address from Received for All Messages~B~smtp.hide_ip
SMTP Delivery Settings~Hide Server Version~B~smtp.hide_server_version
SMTP Protocol Hardening~Require HELO/EHLO~B~smtp.require_helo_ehlo
SMTP Protocol Hardening~Add Return-Path to All Messages~B~smtp.add_return_path
SMTP Protocol Hardening~Dedupe Email Messages~B~smtp.dedupe
SMTP Protocol Hardening~Relay Only if Originators Domain is Local~B~smtp.relay.local_domain_only
SMTP Protocol Hardening~Process SMTP~B~security.intrusion.process_smtp
SMTP Protocol Hardening~Process POP3/IMAP~B~security.intrusion.process_pop3_imap
SMTP Protocol Hardening~Add rDNS Result to Received for All Messages~B~smtp.rdns_in_received
SMTP Protocol Hardening~Set Directory Cache Schedule~V~directory_cache.schedule_raw
SMTP Protocol Hardening~Change Admin URL~V~admin.url
Intrusion Prevention - Block Rules~Block IP - Connections in 1 Minute~V~security.intrusion.block_connections_per_minute.value
Intrusion Prevention - Block Rules~Block IP - Unknown User Delivery Count~V~security.intrusion.block_unknown_user_count.value
Intrusion Prevention - Block Rules~Block IP - Denied for Relaying Too Often~V~security.intrusion.block_relay_denied_count.value
Intrusion Prevention - Block Rules~Block IP - Exceeds RSET Session Count~V~security.intrusion.block_rset_count.value
Intrusion Prevention - Block Rules~Block IP - Message Spam Score~V~security.intrusion.block_spam_score.value
Intrusion Prevention - Block Rules~Block IP - Listed on DNSBL~B~security.intrusion.block_dnsbl_listed.enabled
Intrusion Prevention - Block Rules~Block IP - Exceeds Failed Login Attempts~V~security.intrusion.block_failed_logins.value
Intrusion Prevention - Block Rules~Amount of Time IP is Blocked (minutes)~V~security.intrusion.block_duration_minutes
Intrusion Prevention - Block Rules~Refuse Blocked IP Address~B~security.intrusion.refuse_blocked_ip
Intrusion Prevention - Block Rules~Close Blocked Connection~B~security.intrusion.close_blocked_connection
Intrusion Prevention - Block Rules~Close All Other Connections from Blocked IP~B~security.intrusion.close_all_other_connections
Intrusion Prevention - Block Rules~Cross Session Processing~B~security.intrusion.cross_session_processing
Rejection Rules and Access~Use DNSBL~B~security.dnsbl.use
Rejection Rules and Access~Close Connections for DNSBL Sessions~B~security.dnsbl.close_sessions
Rejection Rules and Access~Use IP Reputation~B~security.ip_reputation.use
Rejection Rules and Access~Reject if Originators IP has no rDNS~B~security.reject_no_rdns
Rejection Rules and Access~Reject if Originators Domain Does Not Exist~B~security.reject_domain_no_mx
Rejection Rules and Access~Reject if Originators Domain is Local and Not Authorized~B~smtp.relay.local_domain_only
Rejection Rules and Access~Set customers-stat@parsavan.com~X~
Rejection Rules and Access~Disable AntiSpam Live~R~security.antispam_live.enabled
Rejection Rules and Access~Remove Old AntiSpam Folders~V~security.antispam_folders.old_count_90d
Rejection Rules and Access~Password Policy Min Length~V~security.password_policy.min_length
Rejection Rules and Access~Set Admin Email~V~monitor.alert_email
Rejection Rules and Access~Change Admin Port~B~admin.port_changed_from_default
Rejection Rules and Access~Block Outgoing Port 9001~B~security.port_9001_egress.blocked
Archive Settings~Archive to Directory~V~icewarp.archive.default
Archive Settings~Number of Used Seats / License Max Users~V~icewarp.license.max_users_raw
Archive Settings~Integrate Archive with IMAP Folder~B~archive.integrate_with_imap
Archive Settings~Do Not Archive Spam~B~archive.do_not_archive_spam
Archive Settings~Enable Daytime Clock Synchronization~B~icewarp.daytime_clock_sync.enabled
Protocol and Access Hardening~Disable VRFY~B~smtp.deny_vrfy
Protocol and Access Hardening~Disable DIGEST-MD5~R~security.digest_md5.enabled
Protocol and Access Hardening~Session Timeout~V~icewarp.session_timeout_minutes
Protocol and Access Hardening~Enable SSL/TLS~B~smtp.use_tls_ssl
Protocol and Access Hardening~Disable Cloud Features~R~icewarp.cloud_api.autoconfigure
Protocol and Access Hardening~Disable IMAP/POP3~V~service.imap.active
APP OS / Infrastructure~APP OS Version~V~general.os.pretty
APP OS / Infrastructure~Disk (Total GB / Used %)~V~storage.root_fs.total_gb
APP OS / Infrastructure~CPU Usage~V~os.cpu.load1
APP OS / Infrastructure~RAM (Total KB / Available KB)~V~os.memory.total_kb
APP OS / Infrastructure~APP OS Last Update~V~os.last_update_date
APP OS / Infrastructure~Repository Access~B~os.repository_access
APP OS / Infrastructure~Time Sync (OS-level NTP)~B~os.time_sync.synced
Database~Database Type~V~database.type
Database~Database Scope~V~database.scope
Database~MySQL Service Active~V~mysql.service_active
Database~MySQL Version~V~mysql.version_raw
MySQL Server (Remote DB)~MySQL Host~V~mysql.host
MySQL Server (Remote DB)~MySQL Reachable (port 3306)~B~mysql.reachable
MySQL Server (Remote DB)~OS-level Stats~V~mysql.os_note'

_mr_bool_status() {
    case "${1:-}" in
        "") echo "NA" ;;
        1|true|TRUE|True) echo "OK" ;;
        0|false|FALSE|False) echo "FAIL" ;;
        *)
            if [[ "$1" =~ ^-?[0-9]+$ ]]; then
                [ "$1" -ne 0 ] && echo "OK" || echo "FAIL"
            else
                echo "OK"
            fi
            ;;
    esac
}

_mr_render_checklist() {
    local CUR_SECTION="" SECTION LABEL KIND KEYS
    while IFS='~' read -r SECTION LABEL KIND KEYS; do
        [ -z "$SECTION" ] && continue
        if [ "$SECTION" != "$CUR_SECTION" ]; then
            [ -n "$CUR_SECTION" ] && _mr_grid_end_row
            _mr_section_header "$SECTION"
            CUR_SECTION="$SECTION"
            _mr_grid_reset
        fi
        case "$KIND" in
            B) _mr_grid_item "$LABEL" "$(_mr_bool_status "${DATA[$KEYS]:-}")" ;;
            R)
                local RAW="${DATA[$KEYS]:-}"
                case "$RAW" in
                    1|true|TRUE|True) _mr_grid_item "$LABEL" "FAIL" ;;
                    0|false|FALSE|False) _mr_grid_item "$LABEL" "OK" ;;
                    *) _mr_grid_item "$LABEL" "NA" ;;
                esac
                ;;
            X) _mr_grid_item "$LABEL" "NA" ;;
            V) _mr_grid_item "$LABEL" "$([ -n "${DATA[$KEYS]:-}" ] && echo "INFO" || echo "NA")" ;;
            H)
                local WORST="OK" K RESULT
                IFS=',' read -ra _HK <<< "$KEYS"
                for K in "${_HK[@]}"; do
                    RESULT="${HEALTH[$K]:-skip}"
                    [ "$RESULT" = "fail" ] && WORST="FAIL"
                    [ "$RESULT" = "warn" ] && [ "$WORST" != "FAIL" ] && WORST="WARN"
                done
                _mr_grid_item "$LABEL" "$WORST"
                ;;
        esac
    done <<< "$_MR_ITEMS"
    _mr_grid_end_row
}

###############################################################################
# Cover letter page
###############################################################################

_mr_cover_letter() {
    local HOST="${DATA[agent.hostname]:-unknown}"
    local GEN="${DATA[agent.time]:-unknown}"
    local COMPANY="${DATA[general.company]:-Client}"
    local OVERALL="${DATA[health.summary.overall]:-n/a}"
    local FAILED="${DATA[health.summary.failed]:-0}"
    local WARNINGS="${DATA[health.summary.warnings]:-0}"
    local CHECKED="${DATA[health.summary.total_checks]:-0}"

    _mr_rect 0 0 "$MR_PAGE_W" "$MR_PAGE_H" "$MR_C_CREAM"
    _mr_rect 0 700 "$MR_PAGE_W" 92 "$MR_C_TERRACOTTA_DARK"
    _mr_rect 0 692 "$MR_PAGE_W" 8 "$MR_C_AMBER"
    _mr_text "$MR_MARGIN" 750 "IceWarp Health Check Report" "F2" 21 "$MR_C_WHITE"
    _mr_text "$MR_MARGIN" 726 "Prepared for ${COMPANY}" "F3" 12 "$MR_C_WHITE"

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
    local ITEMS=("OK:Configured correctly" "WARN:Needs review" "FAIL:Needs attention" "NA:Not applicable" "INFO:Informational value")
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
