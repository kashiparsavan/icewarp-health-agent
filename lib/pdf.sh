#!/bin/bash

###############################################################################
#
# PDF Report Writer (M5)
#
# Deliberately dependency-free: this agent runs unattended on customer
# production IceWarp mail servers, and we can't assume python3/reportlab/
# wkhtmltopdf/pandoc are installed there (and won't have internet access to
# install them). So the report is written directly in the PDF file format -
# a well-known technique for simple single-column monospace text reports -
# using only bash + printf + wc. No new runtime dependency is introduced.
#
# Produces one PDF with a Health Summary section followed by the full raw
# data table, paginated automatically.
#
###############################################################################

PDF_PAGE_WIDTH=612
PDF_PAGE_HEIGHT=792
PDF_MARGIN_LEFT=40
PDF_MARGIN_TOP=760
PDF_LINE_HEIGHT=12
PDF_FONT_SIZE=9
PDF_LINES_PER_PAGE=58
PDF_MAX_LINE_CHARS=112   # keeps text inside the printable width at 9pt Helvetica

_pdf_escape() {
    local S="$1"
    # Strip anything outside printable ASCII to keep the PDF string literal
    # syntax simple and safe (no encoding edge cases to worry about).
    S="$(printf '%s' "$S" | LC_ALL=C tr -c '\40-\176' '?')"
    S="${S//\\/\\\\}"
    S="${S//(/\\(}"
    S="${S//)/\\)}"
    if [ "${#S}" -gt "$PDF_MAX_LINE_CHARS" ]; then
        S="${S:0:$((PDF_MAX_LINE_CHARS-3))}..."
    fi
    printf '%s' "$S"
}

# Builds one content stream (a page worth of text) from an array of lines.
_pdf_build_stream() {
    local -n LINES_REF=$1
    local OUT="BT /F1 ${PDF_FONT_SIZE} Tf ${PDF_LINE_HEIGHT} TL ${PDF_MARGIN_LEFT} ${PDF_MARGIN_TOP} Td"$'\n'
    local FIRST=1
    local LINE ESCAPED
    for LINE in "${LINES_REF[@]}"; do
        ESCAPED="$(_pdf_escape "$LINE")"
        if [ "$FIRST" -eq 1 ]; then
            OUT="${OUT}(${ESCAPED}) Tj"$'\n'
            FIRST=0
        else
            OUT="${OUT}T* (${ESCAPED}) Tj"$'\n'
        fi
    done
    OUT="${OUT}ET"
    printf '%s' "$OUT"
}

# Records the byte offset of object $1 (current EOF position) then appends
# the object's raw bytes to the output file.
_pdf_obj() {
    local NUM="$1"; shift
    PDF_OFFSETS[$NUM]="$(wc -c < "$PDF_OUT_FILE")"
    printf '%s' "$1" >> "$PDF_OUT_FILE"
}

_pdf_write_file() {
    local OUT_PDF="$1"
    local -n PAGES_REF=$2
    local P="${#PAGES_REF[@]}"

    if [ "$P" -eq 0 ]; then
        echo "[WARN] build_pdf: nothing to render, skipping PDF output" >&2
        return 1
    fi

    local FONT_OBJ=$((3 + 2*P))
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
        local STREAM="${PAGES_REF[$((i-1))]}"
        local STREAM_LEN
        STREAM_LEN="$(printf '%s' "$STREAM" | wc -c)"

        _pdf_obj "$PAGE_NUM" "${PAGE_NUM} 0 obj
<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 ${FONT_OBJ} 0 R >> >> /MediaBox [0 0 ${PDF_PAGE_WIDTH} ${PDF_PAGE_HEIGHT}] /Contents ${CONTENT_NUM} 0 R >>
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

    _pdf_obj "$FONT_OBJ" "${FONT_OBJ} 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
"

    local XREF_START
    XREF_START="$(wc -c < "$OUT_PDF")"
    local TOTAL_OBJS=$((FONT_OBJ + 1))

    {
        printf 'xref\n0 %d\n' "$TOTAL_OBJS"
        printf '0000000000 65535 f \n'
        local n
        for ((n=1; n<=FONT_OBJ; n++)); do
            printf '%010d 00000 n \n' "${PDF_OFFSETS[$n]}"
        done
        printf 'trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n' "$TOTAL_OBJS" "$XREF_START"
    } >> "$OUT_PDF"

    echo "[INFO] PDF report written: $OUT_PDF ($(wc -c < "$OUT_PDF") bytes, ${P} page(s))"
}

###############################################################################
#
# Checklist v1.12 definition
#
# Mirrors the actual paper form (IceWarp CheckList v1.12) section by section.
# Each row: SECTION~LABEL~KIND~KEYS~NOTE
#   KIND=B  bool-style item   -> shows ENABLED / DISABLED / N/A (single key)
#   KIND=V  informational     -> shows the raw value(s) (comma-separated keys
#                                 are joined as "shortname=value")
#   KIND=X  not collected yet -> shows "NOT COLLECTED" (no key needed)
# NOTE is optional - printed in parentheses when the mapping is ambiguous,
# unverified, or otherwise needs a human to confirm it.
#
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

_cl_bool_render() {
    local RAW="$1"
    case "$RAW" in
        1|true|TRUE|True) printf 'ENABLED' ;;
        0|false|FALSE|False) printf 'DISABLED' ;;
        "") printf 'N/A (not found)' ;;
        *) printf '%s' "$RAW" ;;
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

_cl_render_lines() {
    local -n OUT_REF=$1
    local CUR_SECTION=""
    local LINE SECTION LABEL KIND KEYS NOTE
    while IFS='~' read -r SECTION LABEL KIND KEYS NOTE; do
        [ -z "$SECTION" ] && continue
        if [ "$SECTION" != "$CUR_SECTION" ]; then
            [ -n "$CUR_SECTION" ] && OUT_REF+=("")
            OUT_REF+=("--- ${SECTION} ---")
            CUR_SECTION="$SECTION"
        fi
        local TAG VAL
        case "$KIND" in
            B)
                VAL="$(_cl_bool_render "${DATA[$KEYS]:-}")"
                case "$VAL" in
                    ENABLED) TAG="[ON ]" ;;
                    DISABLED) TAG="[OFF]" ;;
                    *) TAG="[?? ]" ;;
                esac
                ;;
            V)
                VAL="$(_cl_value_render "$KEYS")"
                TAG="[i  ]"
                ;;
            X)
                VAL="NOT COLLECTED"
                TAG="[TBD]"
                ;;
            *)
                VAL=""
                TAG="[?? ]"
                ;;
        esac
        local ROW
        ROW="$(printf '%s %-46s %s' "$TAG" "$LABEL" "$VAL")"
        [ -n "$NOTE" ] && ROW="${ROW}  (${NOTE})"
        OUT_REF+=("$ROW")
    done <<< "$_CL_ITEMS"
}

build_pdf() {

    local OUT_PDF="${OUTPUT_PDF:-${PROJECT_ROOT}/output/report.pdf}"
    local -a ALL_LINES=()

    ALL_LINES+=("IceWarp Health Check Report  (based on IceWarp CheckList v1.12)")
    ALL_LINES+=("Host: ${DATA[agent.hostname]:-unknown}   Generated: ${DATA[agent.time]:-unknown}   Agent v${DATA[agent.version]:-unknown}")
    ALL_LINES+=("")
    ALL_LINES+=("Company Name: ______________________     Technician: ______________________")
    ALL_LINES+=("IceWarp Version: ${DATA[icewarp.version]:-unknown}   Antispam Update: ${DATA[icewarp.antispam.last_update]:-unknown}   Antivirus Update: ${DATA[icewarp.antivirus.last_update]:-unknown}")
    ALL_LINES+=("Last Backup: ${DATA[icewarp.backup.last_time]:-unknown}   License Expiration: ${DATA[icewarp.license.trial_expiration]:-N/A (perpetual license)}   SSL Expiration: ${DATA[icewarp.ssl.expiration]:-not returned}")
    ALL_LINES+=("")
    ALL_LINES+=("=== Health Summary ===")
    ALL_LINES+=("Overall: ${DATA[health.summary.overall]:-n/a}   Failed: ${DATA[health.summary.failed]:-0}   Warnings: ${DATA[health.summary.warnings]:-0}   Checked: ${DATA[health.summary.total_checks]:-0}")
    ALL_LINES+=("")

    local K
    if [ "${#HEALTH[@]}" -gt 0 ]; then
        for K in $(printf '%s\n' "${!HEALTH[@]}" | sort); do
            ALL_LINES+=("$(printf '[%-4s] %-20s %s' "${HEALTH[$K]}" "$K" "${HEALTH_MSG[$K]:-}")")
        done
    else
        ALL_LINES+=("(health rules did not run)")
    fi

    ALL_LINES+=("")
    ALL_LINES+=("=== IceWarp CheckList v1.12 Walkthrough ===")
    ALL_LINES+=("[ON]=enabled  [OFF]=disabled  [i]=informational value  [TBD]=not collected yet, needs manual check  [??]=unexpected value")
    _cl_render_lines ALL_LINES

    ALL_LINES+=("")
    ALL_LINES+=("=== Collector Status ===")
    local FAILED_COLLECTORS=0
    for K in $(printf '%s\n' "${!STATUS[@]}" | sort); do
        [ "${STATUS[$K]}" = "ok" ] && continue
        FAILED_COLLECTORS=$((FAILED_COLLECTORS+1))
        ALL_LINES+=("$(printf '[%s] %-30s %s' "${STATUS[$K]}" "$K" "${STATUS_MSG[$K]:-}")")
    done
    [ "$FAILED_COLLECTORS" -eq 0 ] && ALL_LINES+=("All collectors ran OK")

    ALL_LINES+=("")
    ALL_LINES+=("=== Appendix: Full Raw Data (${#DATA[@]} keys) ===")
    ALL_LINES+=("")

    for K in $(printf '%s\n' "${!DATA[@]}" | sort); do
        ALL_LINES+=("$(printf '%-42s %s' "$K" "${DATA[$K]}")")
    done

    local -a PAGES_CONTENT=()
    local -a CUR=()
    local COUNT=0 LINE
    for LINE in "${ALL_LINES[@]}"; do
        CUR+=("$LINE")
        COUNT=$((COUNT+1))
        if [ "$COUNT" -ge "$PDF_LINES_PER_PAGE" ]; then
            PAGES_CONTENT+=("$(_pdf_build_stream CUR)")
            CUR=()
            COUNT=0
        fi
    done
    if [ "${#CUR[@]}" -gt 0 ]; then
        PAGES_CONTENT+=("$(_pdf_build_stream CUR)")
    fi

    _pdf_write_file "$OUT_PDF" PAGES_CONTENT
}
