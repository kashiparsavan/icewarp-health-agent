#!/bin/bash

###############################################################################
#
# PDF Report Writer (M5) - v5
#
###############################################################################

PDF_PAGE_W=612
PDF_PAGE_H=792
PDF_MARGIN=36
PDF_TOP_Y=756
PDF_BOTTOM_Y=44
PDF_CONTENT_RIGHT=$((PDF_PAGE_W - PDF_MARGIN))
PDF_CONTENT_W=$((PDF_CONTENT_RIGHT - PDF_MARGIN))

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

_pdf_rect() {
    _PDF_CUR="${_PDF_CUR}${5} rg
${1} ${2} ${3} ${4} re f
"
}

_pdf_text() {
    local ESC
    ESC="$(_pdf_escape "$3")"
    _PDF_CUR="${_PDF_CUR}${6} rg
BT /${4} ${5} Tf ${1} ${2} Td (${ESC}) Tj ET
"
}

_pdf_text_trunc() {
    local MAXCHARS="$7"
    local TXT="$3"
    [ "${#TXT}" -gt "$MAXCHARS" ] && TXT="${TXT:0:$((MAXCHARS-1))}."
    _pdf_text "$1" "$2" "$TXT" "$4" "$5" "$6"
}

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
    local BCOLOR="$(_badge_color "$BKIND")"
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
    local LBLS=("ON=enabled" "OFF=disabled" "TBD=not collected yet" "INFO=informational value")
    local LKINDS=("ON" "OFF" "TBD" "INFO")
    local I
    for I in 0 1 2 3; do
        local BC="$(_badge_color "${LKINDS[$I]}")"
        _pdf_rect "$LX" "$((_PDF_Y - 3))" 26 11 "$BC"
        _pdf_text "$((LX + 30))" "$_PDF_Y" "${LBLS[$I]}" "F1" 8 "$PDF_C_TEXT"
        LX=$((LX + 30 + 6*${#LBLS[$I]} + 14))
    done
    _PDF_Y=$((_PDF_Y - 20))
}

# ---- Get status from watchdog or fallback to calculation ----
_get_status_for_os_item() {
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
            FAIL) BKIND="FAIL" ;;
            *) BKIND="INFO" ;;
        esac
        printf '%s|%s|%s' "$BKIND" "$STATUS" "$MSG"
    else
        # Fallback: compute status directly from raw data
        local BKIND="INFO"
        local MSG=""
        case "$KEYS" in
            *os.cpu.load1*)
                local LOAD1="${DATA[os.cpu.load1]:-0}"
                local CORES="${DATA[os.cpu.count]:-1}"
                LOAD1=$(echo "$LOAD1" | tr ',' '.' | sed 's/[^0-9.]//g')
                [ -z "$LOAD1" ] && LOAD1="0"
                if [[ "$CORES" =~ ^[0-9]+$ ]] && [[ "$CORES" -gt 0 ]]; then
                    local PCT=$(awk -v l="$LOAD1" -v c="$CORES" 'BEGIN {printf "%.2f", (l/c)*100}')
                    if (( $(echo "$PCT > 50" | bc -l 2>/dev/null) )); then
                        BKIND="WARN"
                        MSG="CPU load is ${PCT}% (threshold: 50%)"
                    else
                        BKIND="PASS"
                        MSG="CPU load is ${PCT}% (OK)"
                    fi
                fi
                ;;
        esac
        printf '%s|%s|%s' "$BKIND" "$BKIND" "$MSG"
    fi
}

_CL_ITEMS='DNS & Mail Flow Verification~Check PTR~F~dns.ptr.exists~real reverse-DNS lookup for ${dns.ptr.ip} -> ${dns.ptr.result} | matches mail hostname: ${dns.ptr.matches_hostname}
DNS & Mail Flow Verification~Check SPF~F~dns.spf.found~real TXT lookup for ${dns.spf.domain} | server IP covered: ${dns.spf.includes_server_ip} via ${dns.spf.ip_coverage_via}
DNS & Mail Flow Verification~Check DKIM~F~dns.dkim.found~real TXT lookup, selector found: ${dns.dkim.selector_found} (tried: ${dns.dkim.selectors_tried})
DNS & Mail Flow Verification~Check DMARC~F~dns.dmarc.found~real TXT lookup | policy: p=${dns.dmarc.policy}
DNS & Mail Flow Verification~Check TLS and Start TLS~F~smtp.starttls_live_test~live STARTTLS handshake test on port 25, not a config check
DNS & Mail Flow Verification~Check DNS Server~V~dns.configured_server~IceWarps configured forwarders - the OS resolver actually used by dig is a separate thing, see Test DNS Lookup / Resolver External Test
DNS & Mail Flow Verification~Test DNS Lookup~F~dns.lookup_test.ok~real dig lookup for our own domain (${dns.lookup_test.host})
DNS & Mail Flow Verification~Resolver External Test~F~dns.resolver.external_test_ok~real dig lookup for an external domain (${dns.resolver.external_test_host}) - confirms the resolver can reach arbitrary destination domains, not just our own
Logging~Enable Logging - Authentication~B~logging.auth_log_level~
Logging~Enable Logging - Maintenance~B~logging.maintenance_log_level~
Logging~Enable MailFlow Log~B~logging.mailqueue.level~
Logging~Enable SQL Failed Logs~B~logging.sql_log_type~
Backup, Watchdog and Monitoring~Enable System Backup~B~icewarp.backup.auto_enabled~
Backup, Watchdog and Monitoring~Last Backup Date and Time~V~icewarp.backup.last_time~
Backup, Watchdog and Monitoring~Enable Database Backup~B~icewarp.database_backup.enabled~verified via C_System_Tools_Backup_DB_Accounts
Backup, Watchdog and Monitoring~Configure Archive Backup Settings~B~archive.backup.active~
Backup, Watchdog and Monitoring~Enable System Watchdog~W~watchdog.control~smtp=${watchdog.smtp},pop3=${watchdog.pop3},im=${watchdog.im},gw=${watchdog.gw}
Backup, Watchdog and Monitoring~Remote Server Watchdog~W~watchdog.remoteserver.enable~down_after_min=${watchdog.remoteserver.down_after_minutes},report_email=${watchdog.remoteserver.report_email}
Backup, Watchdog and Monitoring~Enable System Monitor (Mem/Disk/CPU)~B~monitor.enabled~checks whether monitoring itself is configured/active - current threshold pass/fail is a separate matter, see Health Summary section
Migration Safety~Migration Active~R~icewarp.migration.active~must be disabled - an active migration left running by mistake has previously caused a full outage on this environment, verified via C_System_Tools_Migration_Active
Migration Safety~Migration Source Server~V~icewarp.migration.server~informational - the configured source host, populated even when migration is inactive
Migration Safety~Migration Ever Started~M~icewarp.migration.stat_started~a nonzero start timestamp exists (see icewarp.migration.stat_start_human) - a softer signal than Active, may just be historical
Migration Safety~Migration Has Errors~R~icewarp.migration.has_errors~see icewarp.migration.stat_errors for the count, verified via C_System_Tools_Migration_Stat_Errors
Storage, Certificates and Services~Check for Storage Locations~V~icewarp.path.mail~
Storage, Certificates and Services~Check for Certificates~V~icewarp.ssl.expiration,icewarp.ssl.days_left~live-checked via openssl against the mail domain on port 443, not just a local file path
Storage, Certificates and Services~RBL Valli Check (is our IP blacklisted)~R~security.rbl_self_check.listed~queries Spamhaus/SpamCop/SORBS/Barracuda directly against our own IP
Storage, Certificates and Services~Enable Full Text Search Services~P~fulltext.enabled~this service is expected to be OFF - flagged if active
Storage, Certificates and Services~Reject if SMTP AUTH Different from Sender~B~smtp.reject_auth_sender_mismatch~
Storage, Certificates and Services~2FA~R~security.login.2fa_bypass_enabled~this is the BYPASS flag (true=bypass allowed=bad), not whether 2FA is required - needs correct property confirmed
Storage, Certificates and Services~Archive Active~B~archive.active~
Storage, Certificates and Services~Daily Send Email limit~Z~domain.primary.daily_send_messages_limit~for the primary/first domain found - 0 means unlimited, which is a real risk worth flagging
SMTP Delivery Settings~Max Message Size (MB)~V~smtp.max_message_size.mb~
SMTP Delivery Settings~Delivery Reports~B~smtp.delivery_reports_enabled~verified via C_Mail_SMTP_Other_Disable_DSN (inverted)
SMTP Delivery Settings~Use TLS/SSL (Secured Delivery)~B~smtp.use_tls_ssl~
SMTP Delivery Settings~Process Incoming Messages in MDA Queue~B~smtp.use_incoming_queue~
SMTP Delivery Settings~Use MDA Queue for Internal Message Delivery~B~smtp.mda_internal_delivery~may be the same underlying setting as the item above, needs confirming
SMTP Delivery Settings~Maximum Number of Simultaneous Threads~V~smtp.incoming_queue_threads~was pointing at smtp.thread_cache (a different System>Services setting) - fixed to the actual Mail>General>Advanced property
SMTP Delivery Settings~Hide IP Address from Received for All Messages~B~smtp.hide_ip~
SMTP Delivery Settings~Hide Server Version~B~smtp.hide_server_version~
SMTP Protocol Hardening~Require HELO/EHLO~B~smtp.require_helo_ehlo~
SMTP Protocol Hardening~Add Return-Path to All Messages~B~smtp.add_return_path~
SMTP Protocol Hardening~Dedupe Email Messages~B~smtp.dedupe~
SMTP Protocol Hardening~Relay Only if Originators Domain is Local~B~smtp.relay.local_domain_only~
SMTP Protocol Hardening~Process SMTP~B~security.intrusion.process_smtp~ambiguous, a separate watchdog-level flag may also apply - needs confirming
SMTP Protocol Hardening~Process POP3/IMAP~B~security.intrusion.process_pop3_imap~ambiguous, see note above
SMTP Protocol Hardening~Add rDNS Result to Received for All Messages~B~smtp.rdns_in_received~
SMTP Protocol Hardening~Set Directory Cache Schedule~B~directory_cache.scheduled~raw schedule format still not decoded (see appendix), but whether it is set at all is reliable
SMTP Protocol Hardening~Change Admin URL~B~admin.url_changed_from_default~heuristic: compares the URL path against IceWarps default "/admin/" - no dedicated tool.sh boolean exists for this
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
Rejection Rules and Access~Reject if Originators Domain is Local and Not Authorized~B~smtp.relay.local_domain_only~likely a duplicate of Relay Only if Originators Domain is Local - same underlying property (C_Mail_Security_Protection_LocalDomain), no distinct property found
Rejection Rules and Access~Set customers-stat@parsavan.com~V~monitor.alert_email~confirmed via WebAdmin (API Console): same property as "Set Admin Email" (C_System_Tools_Monitor_ReportAddress) - if the live value doesnt match the expected address, this field may need updating in WebAdmin, or it may support multiple semicolon-separated recipients where only one shows
Rejection Rules and Access~Disable AntiSpam Live~R~security.antispam_live.enabled~verified via C_AS_Live_Enable (true=live enabled=bad, inverted)
Rejection Rules and Access~Remove Old AntiSpam Folders~V~security.antispam_folders.old_count_90d~folders older than 90 days - agent is read-only, reports count for manual review, never deletes
Rejection Rules and Access~Password Policy Min Length~V~security.password_policy.min_length~
Rejection Rules and Access~Set Admin Email~V~monitor.alert_email~
Rejection Rules and Access~Change Admin Port~B~admin.port_changed_from_default~
Rejection Rules and Access~Block Outgoing Port 9001~G~security.port_9001_egress.blocked~checked via firewalld/iptables directly, see security.port_9001_egress.method
Archive Settings~Archive to Directory~V~icewarp.archive.default~
Archive Settings~Number of Used Seats / License Max Users~V~icewarp.license.max_users_raw~best-effort from C_License_XML - tag name unconfirmed, see icewarp.license.max_users_note if empty
Archive Settings~Integrate Archive with IMAP Folder~B~archive.integrate_with_imap~
Archive Settings~Do Not Archive Spam~B~archive.do_not_archive_spam~
Archive Settings~Enable Daytime Clock Synchronization~B~icewarp.daytime_clock_sync.enabled~
Protocol and Access Hardening~Disable VRFY~B~smtp.deny_vrfy~
Protocol and Access Hardening~Disable DIGEST-MD5~R~security.digest_md5.enabled~true means DIGEST-MD5 is still enabled, which is bad - inverted polarity
Protocol and Access Hardening~Session Timeout~V~icewarp.session_timeout_minutes~verified via C_System_Adv_Protocols_SessionTimeOut
Protocol and Access Hardening~Enable SSL/TLS~B~smtp.use_tls_ssl~may be a broader admin/IMAP/POP3 toggle distinct from the SMTP item above, needs confirming
Protocol and Access Hardening~Disable Cloud Features~R~icewarp.cloud_api.autoconfigure~verified via C_CloudAPI_AutoConfigure (true=cloud autoconfig active=bad, inverted)
Protocol and Access Hardening~Disable IMAP/POP3~V~service.imap.active,service.pop3.active~
APP OS / Infrastructure~APP OS Version~V~general.os.pretty~
APP OS / Infrastructure~Disk (Total GB / Used %)~V~storage.root_fs.total_gb,storage.root_fs.used_percent~
APP OS / Infrastructure~CPU Usage~V~os.cpu.load1~1-min load average collected, not literal CPU percent - needs confirming if acceptable
APP OS / Infrastructure~RAM (Total KB / Available KB)~V~os.memory.total_kb,os.memory.available_kb~
APP OS / Infrastructure~APP OS Last Update~V~os.last_update_date~from dnf/yum/apt history
APP OS / Infrastructure~Repository Access~B~os.repository_access~live repo reachability check via dnf/yum/apt
APP OS / Infrastructure~Time Sync (OS-level NTP)~B~os.time_sync.synced~via timedatectl/chronyc - distinct from IceWarps own daytime sync (see icewarp.daytime_clock_sync.enabled)
Database~Database Type~V~database.type~
Database~Database Scope~V~database.scope~local = same server as IceWarp, remote = separate database server
Database~MySQL Service Active~V~mysql.service_active~only populated when database is MySQL and running locally
Database~MySQL Version~V~mysql.version_raw~only populated when database is MySQL and running locally
Database~MySQL OS version~L~general.os.pretty~
Database~MySQL Disk (Total GB / Used %)~L~storage.root_fs.total_gb~
Database~MySQL CPU Usage~L~os.cpu.load1~1-min load average, not literal CPU percent
Database~MySQL RAM (Total KB / Available KB)~L~os.memory.total_kb~
Database~MySQL OS Last Update~L~os.last_update_date~
Database~MySQL Repository Access~L~os.repository_access~
Database~MySQL Time Sync~L~os.time_sync.synced~
MySQL Server (Remote DB)~MySQL Host~V~mysql.host~
MySQL Server (Remote DB)~MySQL Reachable (port 3306)~B~mysql.reachable~TCP reachability only - no query access without credentials
MySQL Server (Remote DB)~OS-level Stats~V~mysql.os_note~this agent has no access to the remote box - needs a second agent run there, or SSH access'

_cl_bool_kind() {
    local V="${1:-}"
    case "$V" in
        "") echo "TBD:N/A" ;;
        1|true|TRUE|True) echo "ON:ENABLED" ;;
        0|false|FALSE|False) echo "OFF:DISABLED" ;;
        *)
            if [[ "$V" =~ ^-?[0-9]+$ ]]; then
                [ "$V" -ne 0 ] && echo "ON:ENABLED (level ${V})" || echo "OFF:DISABLED"
            else
                echo "INFO:$V"
            fi
            ;;
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
        local JOINED="$(IFS=', '; echo "${PARTS[*]}")"
        printf '%s' "$JOINED"
    else
        printf '%s' "${DATA[$KEYS]:-(empty)}"
    fi
}

_health_worst_of() {
    local KEYS="$1"
    local WORST="pass"
    local -a MSGS=()
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
    printf '%s|%s' "$WORST" "$JOINED_MSG"
}

_render_note_template() {
    local TEMPLATE="$1"
    local RESULT="$TEMPLATE"
    while [[ "$RESULT" =~ \$\{([a-zA-Z0-9_.]+)\} ]]; do
        local REF="${BASH_REMATCH[1]}"
        local VAL="${DATA[$REF]:-?}"
        RESULT="${RESULT//\$\{${REF}\}/${VAL}}"
    done
    printf '%s' "$RESULT"
}

_render_checklist() {
    local CUR_SECTION=""
    local SECTION LABEL KIND KEYS NOTE
    while IFS='~' read -r SECTION LABEL KIND KEYS NOTE; do
        [ -z "$SECTION" ] && continue

        if [[ "$SECTION" == "MySQL Server"* ]] && [ "${DATA[database.scope]:-}" != "remote" ]; then
            local NA_REASON="not applicable"
            case "${DATA[database.type]:-}" in
                sqlite) NA_REASON="not applicable - this install uses SQLite, no MySQL server involved" ;;
                mysql) NA_REASON="not applicable - MySQL runs locally on this same server, see the Database section above" ;;
                *) NA_REASON="not applicable - database type could not be determined" ;;
            esac
            if [ "$SECTION" != "$CUR_SECTION" ]; then
                _layout_section_header "$SECTION"
                CUR_SECTION="$SECTION"
                _layout_row_index=0
            fi
            _layout_row "$LABEL" "N/A" "OFF" "N/A" "$NA_REASON"
            continue
        fi

        if [ "$SECTION" != "$CUR_SECTION" ]; then
            _layout_section_header "$SECTION"
            CUR_SECTION="$SECTION"
            _layout_row_index=0
        fi

        # Special handling for Database Type
        if [ "$LABEL" = "Database Type" ] && [ "${DATA[database.type]:-}" = "sqlite" ]; then
            _layout_row "$LABEL" "sqlite" "WARN" "WARN" "SQLite is not recommended for production - use MySQL"
            continue
        fi

        # Special handling for OS items with watchdog or fallback
        if [ "$KIND" = "V" ] && [[ "$KEYS" == *"storage.root_fs.used_percent"* || "$KEYS" == *"os.cpu.load1"* || "$KEYS" == *"os.memory.total_kb"* || "$KEYS" == *"os.last_update_date"* ]]; then
            local WD_INFO="$(_get_status_for_os_item "$KEYS")"
            local WD_BKIND="${WD_INFO%%|*}"
            local WD_STATUS="${WD_INFO#*|}"
            local WD_MSG="${WD_INFO##*|}"
            local WD_BTEXT="$WD_BKIND"
            local VAL="$(_cl_value_render "$KEYS")"
            local NOTE_FINAL="$NOTE"
            [ -n "$WD_MSG" ] && [ "$WD_MSG" != "$VAL" ] && NOTE_FINAL="${NOTE_FINAL} | watchdog: ${WD_MSG}"
            _layout_row "$LABEL" "$VAL" "$WD_BKIND" "$WD_BTEXT" "$NOTE_FINAL"
            continue
        fi

        case "$KIND" in
            B)
                local RESULT="$(_cl_bool_kind "${DATA[$KEYS]:-}")"
                _layout_row "$LABEL" "${RESULT#*:}" "${RESULT%%:*}" "${RESULT%%:*}" "$NOTE"
                ;;
            V)
                local VAL="$(_cl_value_render "$KEYS")"
                _layout_row "$LABEL" "$VAL" "INFO" "INFO" "$NOTE"
                ;;
            X)
                _layout_row "$LABEL" "not collected" "TBD" "TBD" "$NOTE"
                ;;
            W)
                local RESULT="$(_cl_bool_kind "${DATA[$KEYS]:-}")"
                local DETAIL="$(_render_note_template "$NOTE")"
                _layout_row "$LABEL" "${RESULT#*:}" "${RESULT%%:*}" "${RESULT%%:*}" "$DETAIL"
                ;;
            H)
                local COMBINED="$(_health_worst_of "$KEYS")"
                local WORST="${COMBINED%%|*}"
                local MSG="${COMBINED#*|}"
                local BKIND="PASS"
                [ "$WORST" = "warn" ] && BKIND="WARN"
                [ "$WORST" = "fail" ] && BKIND="FAIL"
                _layout_row "$LABEL" "" "$BKIND" "$(echo "$WORST" | tr '[:lower:]' '[:upper:]')" "${MSG:-$NOTE}"
                ;;
            G)
                local RAW="${DATA[$KEYS]:-}"
                case "$RAW" in
                    1|true|TRUE|True) _layout_row "$LABEL" "YES" "ON" "OK" "$NOTE" ;;
                    0|false|FALSE|False) _layout_row "$LABEL" "NO" "FAIL" "NOT BLOCKED" "$NOTE" ;;
                    *) _layout_row "$LABEL" "not collected" "TBD" "TBD" "$NOTE" ;;
                esac
                ;;
            R)
                local RAW="${DATA[$KEYS]:-}"
                case "$RAW" in
                    1|true|TRUE|True) _layout_row "$LABEL" "YES" "FAIL" "BAD" "$NOTE" ;;
                    0|false|FALSE|False) _layout_row "$LABEL" "NO" "ON" "OK" "$NOTE" ;;
                    *) _layout_row "$LABEL" "not collected" "TBD" "TBD" "$NOTE" ;;
                esac
                ;;
            L)
                if [ "${DATA[database.type]:-}" = "mysql" ] && [ "${DATA[database.scope]:-}" = "local" ]; then
                    _layout_row "$LABEL" "${DATA[$KEYS]:-(empty)}" "INFO" "INFO" "same host as IceWarp - mirrors the APP OS value"
                else
                    _layout_row "$LABEL" "N/A" "OFF" "N/A" "not applicable - MySQL is not local (see Database / MySQL Server sections)"
                fi
                ;;
            P)
                local RAW="${DATA[$KEYS]:-}"
                case "$RAW" in
                    ""|0|false|FALSE|False) _layout_row "$LABEL" "off" "ON" "OK" "$NOTE" ;;
                    *) _layout_row "$LABEL" "$RAW" "FAIL" "ACTIVE" "$NOTE" ;;
                esac
                ;;
            Z)
                local RAW="${DATA[$KEYS]:-}"
                if [ "$RAW" = "0" ]; then
                    _layout_row "$LABEL" "0 (= unlimited)" "WARN" "WARN" "${NOTE:-a limit of 0 means unlimited - consider setting a real value}"
                elif [ -n "$RAW" ]; then
                    _layout_row "$LABEL" "$RAW" "INFO" "INFO" "$NOTE"
                else
                    _layout_row "$LABEL" "not collected" "TBD" "TBD" "$NOTE"
                fi
                ;;
            F)
                local RAW="${DATA[$KEYS]:-}"
                local DETAIL="$(_render_note_template "$NOTE")"
                case "$RAW" in
                    1|true|TRUE|True) _layout_row "$LABEL" "found (live query)" "ON" "FOUND" "$DETAIL" ;;
                    0|false|FALSE|False) _layout_row "$LABEL" "not found (live query)" "FAIL" "MISSING" "$DETAIL" ;;
                    *) _layout_row "$LABEL" "not collected" "TBD" "TBD" "$DETAIL" ;;
                esac
                ;;
            M)
                local RAW="${DATA[$KEYS]:-}"
                case "$RAW" in
                    1|true|TRUE|True) _layout_row "$LABEL" "YES" "WARN" "WARN" "$NOTE" ;;
                    0|false|FALSE|False) _layout_row "$LABEL" "NO" "ON" "OK" "$NOTE" ;;
                    *) _layout_row "$LABEL" "not collected" "TBD" "TBD" "$NOTE" ;;
                esac
                ;;
        esac
    done <<< "$_CL_ITEMS"
}

_render_health_summary() {
    _layout_section_header "Health Summary"
    _layout_row_index=0
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

_pdf_obj() {
    local NUM="$1"; shift
    PDF_OFFSETS[$NUM]="$(wc -c < "$PDF_OUT_FILE")"
    printf '%s' "$1" >> "$PDF_OUT_FILE"
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
    local KIDS="" i
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
        for ((n=1; n<=F_OBL; n++)); do printf '%010d 00000 n \n' "${PDF_OFFSETS[$n]}"; done
        printf 'trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n' "$TOTAL_OBJS" "$XREF_START"
    } >> "$OUT_PDF"
    echo "[INFO] PDF report written: $OUT_PDF ($(wc -c < "$OUT_PDF") bytes, ${P} page(s))"
}

build_pdf() {
    local OUT_PDF="${OUTPUT_PDF:-${PROJECT_ROOT}/output/report.pdf}"
    _PDF_PAGES=()
    _PDF_CUR=""
    _PDF_Y=$PDF_TOP_Y

    _layout_cover
    [ "${#HEALTH[@]}" -gt 0 ] && _render_health_summary
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
