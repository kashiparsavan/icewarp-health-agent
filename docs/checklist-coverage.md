# IceWarp Checklist v1.12 - Complete Coverage Report

Last updated: 2026-10-19 (after Docker migration and configurator implementation)

Legend:
- FULL: fully collected and evaluated (PASS/WARN/CRITICAL)
- PARTIAL: collected but evaluation needs review or is intentionally informational
- MISSING: not yet implemented
- N/A: not applicable to this environment (e.g., SQLite install without remote MySQL)
- INFO: collected but only displayed as informational

## Original Checklist (99 items)

| # | Section | Item | Status | Collector / Key | Notes |
|---|---------|------|--------|-----------------|-------|
| 1 | DNS | Check PTR | FULL | dns/ptr.sh -> dns.ptr.checked | |
| 2 | DNS | Check SPF | FULL | dns/spf.sh -> dns.spf.checked | |
| 3 | DNS | Check DKIM | FULL | dns/dkim.sh -> dns.dkim.checked | |
| 4 | DNS | Check DMARC | FULL | dns/dmarc.sh -> dns.dmarc.checked | |
| 5 | DNS | Check TLS and Start TLS | FULL | dns/starttls.sh + mailserver/tls_ssl.sh | |
| 6 | DNS | Check DNS Server | FULL | dns/dns_server.sh -> dns.configured_server | |
| 7 | Logging | Enable Logging - Authentication and Maintenance | FULL | logging/sql_auth_log.sh -> logging.auth_log_level + maintenance_log_level | KIND=L fixed (0=CRITICAL, non-zero=PASS) |
| 8 | Logging | Enable MailFlow Log | FULL | logging/mailqueue.sh -> logging.mailqueue.level | KIND=L |
| 9 | Logging | Enable SQL Failed Logs | FULL | logging/sql_auth_log.sh -> logging.sql_log_type | KIND=L |
| 10 | MailServer | Daily Send Email limit | FULL | icewarp/domain_limits.sh -> domain.*.daily_send_messages_limit | KIND=Z (0=WARN) |
| 11 | Security | Block outgoing port 9001 | FULL | security/port_9001.sh -> security.port_9001_egress.blocked | firewalld check |
| 12 | Backup | Enable System Backup | FULL | icewarp/backup.sh -> icewarp.backup.auto_enabled | |
| 13 | Backup | Enable Database Backup | FULL | icewarp/database_backup.sh -> backup.db.accounts.enabled + as + gw | Split into 3 separate items (see new items 100-102) |
| 14 | Backup | Configure Archive Backup Settings | FULL | icewarp/backup.sh -> archive.backup.active | |
| 15 | Watchdog | Enable System Watchdog | FULL | icewarp/watchdog.sh -> watchdog.control | Main control + 5 per-service items (see new items 103-107) |
| 16 | Monitor | Enable System Monitor | FULL | icewarp/system_monitor.sh -> monitor.enabled | Thresholds displayed in note |
| 17 | Storage | Check for Storage Locations | FULL | icewarp/storage_paths.sh | INFO display |
| 18 | SSL | Check for Certificates | FULL | icewarp/certificate.sh -> icewarp.ssl.* | New wildcard cert installed (expires Dec 11 2026) |
| 19 | Security | RBL Valli Check | FULL | security/rbl_self_check.sh -> security.rbl_self_check.listed | Live DNS query to 4 RBLs |
| 20 | Mail | Enable Full Text Search Services | FULL | fulltext/scanner_queue.sh -> fulltext.enabled | KIND=P |
| 21 | Security | Reject if SMTP AUTH Different from Sender | FULL | mailserver/reject_auth_mismatch.sh | |
| 22 | Security | 2FA | FULL | security/login_policy.sh -> security.login.2fa_bypass_enabled | KIND=R (0=PASS) |
| 23 | DNS | Test DNS Lookup | FULL | dns/dns_server.sh -> dns.lookup_test.* | |
| 24 | SMTP | Max Message Size | FULL | smtp/max_message_size.sh | INFO display |
| 25 | Mail | Delivery Reports | FULL | mailserver/smtp_limits.sh -> smtp.delivery_reports_enabled | |
| 26 | SMTP | Use TLS/SSL (Secured Delivery) | FULL | mailserver/tls_ssl.sh -> smtp.use_tls_ssl | |
| 27 | Queue | Process Incoming Messages in MDA Queue | FULL | mailserver/mda_queue.sh -> smtp.use_incoming_queue | |
| 28 | Queue | Use MDA Queue for Internal Message Delivery | FULL | mailserver/mda_queue.sh -> smtp.mda_internal_delivery | Distinct property confirmed |
| 29 | SMTP | Maximum Number of Simultaneous Threads | FULL | smtp/max_connections.sh -> smtp.incoming_queue_threads | Expected: 10 |
| 30 | SMTP | Hide IP Address from Received | FULL | mailserver/hide_ip.sh -> smtp.hide_ip | |
| 31 | SMTP | Hide Server Version | FULL | mailserver/hide_ip.sh -> smtp.hide_server_version | |
| 32 | SMTP | Require HELO/EHLO | FULL | mailserver/security_advanced.sh -> smtp.require_helo_ehlo | |
| 33 | SMTP | Add Return-Path to All Messages | FULL | mailserver/rdns_returnpath.sh -> smtp.add_return_path | |
| 34 | SMTP | Dedupe Email Messages | FULL | mailserver/dedupe.sh -> smtp.dedupe | |
| 35 | Relay | Relay Only if Originator's Domain is Local | FULL | smtp/relay.sh -> smtp.relay.local_domain_only | |
| 36 | Watchdog | Process SMTP | FULL | security/intrusion_prevention.sh -> security.intrusion.process_smtp | |
| 37 | Watchdog | Process POP3/IMAP | FULL | security/intrusion_prevention.sh -> security.intrusion.process_pop3_imap | |
| 38 | Security | Block IP - Connections in 1 Minute | FULL | security/intrusion_prevention.sh | Expected: 10 |
| 39 | Maintenance | Set Directory Cache Schedule | FULL | icewarp/directory_cache.sh -> directory_cache.scheduled | KIND=B (CRITICAL if not set) |
| 40 | Admin | Change Admin URL | FULL | icewarp/admin_access.sh -> admin.url_changed_from_default | |
| 41 | SMTP | Add rDNS Result to Received | FULL | mailserver/rdns_returnpath.sh -> smtp.rdns_in_received | |
| 42 | Security | Block IP - Unknown User Delivery Count | FULL | security/intrusion_prevention.sh | Expected: 5 |
| 43 | Security | Block IP - Denied for Relaying Too Often | FULL | security/intrusion_prevention.sh | Expected: 5 |
| 44 | Security | Block IP - Exceeds RSET Session Count | FULL | security/intrusion_prevention.sh | Expected: 5 |
| 45 | Security | Block IP - Message Spam Score | FULL | security/intrusion_prevention.sh | Expected: 9.00 |
| 46 | Security | Block IP - Listed on DNSBL | FULL | security/intrusion_prevention.sh | |
| 47 | Security | Amount of Time IP Address is Blocked | FULL | security/intrusion_prevention.sh -> block_duration_minutes | Expected: 30 |
| 48 | Security | Refuse Blocked IP Address | FULL | security/intrusion_prevention.sh | |
| 49 | Security | Close Blocked Connection | FULL | security/intrusion_prevention.sh | |
| 50 | Security | Immediately Close All Other Connections | FULL | security/intrusion_prevention.sh | |
| 51 | Admin | Set customers-stat@parsavan.com | FULL | Custom handler in pdf.sh | Specific check |
| 52 | Security | Disable AntiSpam Live | FULL | security/antispam_live.sh -> security.antispam_live.enabled | KIND=D (0=PASS, 1=WARN) |
| 53 | Security | Reject if SMTP AUTH different from sender (duplicate) | FULL | Same as #21 | Duplicate on source form |
| 54 | Security | Block IP - Exceeds Failed Login Attempts | FULL | security/intrusion_prevention.sh | Expected: 5 |
| 55 | Security | Cross Session Processing | FULL | security/intrusion_prevention.sh | |
| 56 | Security | Use DNSBL | FULL | security/dnsbl_rdns.sh -> security.dnsbl.use | |
| 57 | Security | Reject if Originator's IP has no rDNS | FULL | security/dnsbl_rdns.sh -> security.reject_no_rdns | |
| 58 | Security | Reject if Originator's Domain Does Not Exist | FULL | security/dnsbl_rdns.sh -> security.reject_domain_no_mx | |
| 59 | Security | Reject if Originator's Domain is Local and Not Authorized | FULL | smtp/relay.sh -> smtp.relay.local_domain_only | Same property as #35 |
| 60 | Security | Close Connections for DNSBL Sessions | FULL | security/dnsbl_rdns.sh -> security.dnsbl.close_sessions | |
| 61 | Security | Use IP Reputation | FULL | security/dnsbl_rdns.sh -> security.ip_reputation.use | |
| 62 | Archive | Archive Active | FULL | icewarp/backup.sh -> archive.active | |
| 63 | Security | Password Policy | FULL | security/password_policy.sh | KIND=E (evaluated with min length check) |
| 64 | Admin | Set admin email | FULL | Custom handler | CRITICAL if empty |
| 65 | Maintenance | Remove old AntiSpam folders | FULL | security/cyren_folder.sh -> security.cyren_folder.status | |
| 66 | Admin | Change Admin Port | FULL | icewarp/admin_access.sh -> admin.port_changed_from_default | |
| 67 | Archive | Integrate Archive with IMAP Folder | FULL | icewarp/backup.sh -> archive.integrate_with_imap | Note shows folder name |
| 68 | Archive | Do Not Archive Spam | FULL | icewarp/backup.sh -> archive.do_not_archive_spam | |
| 69 | System | Enable Daytime Clock Synchronization | FULL | icewarp/protocol_advanced.sh -> icewarp.daytime_clock_sync.enabled | |
| 70 | SMTP | Disable VRFY | FULL | security/vrfy.sh -> smtp.deny_vrfy | CRITICAL if VRFY is enabled |
| 71 | Security | Disable DIGEST-MD5 | FULL | security/digest_md5.sh -> security.digest_md5.enabled | KIND=R (false=PASS) |
| 72 | Admin | Session Timeout | FULL | icewarp/protocol_advanced.sh -> icewarp.session_timeout_minutes | INFO display |
| 73 | SSL | Enable SSL/TLS | FULL | mailserver/tls_ssl.sh -> smtp.use_tls_ssl | Same as #26 |
| 74 | System | Disable Cloud Features | FULL | security/cloud_features.sh -> icewarp.cloud_api.autoconfigure | KIND=D (0=PASS) |
| 75 | Services | Disable IMAP/POP3 | FULL | mailserver/process_protocols.sh -> service.imap.active + pop3 | PASS if disabled |
| 76 | Archive | Archive to directory (field) | FULL | icewarp/backup.sh -> icewarp.archive.default | INFO display |
| 77 | License | Number of Used Seats / License max users | FULL | icewarp/license.sh | WARN if unavailable (honest) |
| 78 | AppOS | APP OS version | FULL | general/os.sh -> general.os.pretty | INFO display |
| 79 | AppOS | Disk Total/Usage | FULL | storage/storage.sh -> storage.root_fs.* | WARN >=80%, CRITICAL >=95% |
| 80 | AppOS | CPU usage Percentage | FULL | os/cpu.sh -> os.cpu.load15 | 15-min load, WARN >50%, CRITICAL >95% |
| 81 | AppOS | RAM Total/Usage | FULL | os/memory.sh | WARN >40%, CRITICAL >90% |
| 82 | AppOS | APP OS Last Update | FULL | os/os_update.sh -> os.last_update_date | <7d PASS, 7-30d WARN, >30d CRITICAL |
| 83 | MySQL | MySQL IP Address | N/A | icewarp/database_type.sh -> database.host | Only when remote MySQL detected |
| 84 | AppOS | Repository access | FULL | os/repository_access.sh -> os.repository_access | |
| 85 | AppOS | Time sync | FULL | os/time_sync.sh -> os.time_sync.synced | OS-level NTP (distinct from IceWarp Daytime) |
| 86 | MySQL | MySQL OS version | N/A | Not applicable - SQLite install | |
| 87 | MySQL | Disk Total/Usage | N/A | Not applicable - SQLite install | |
| 88 | MySQL | CPU usage Percentage | N/A | Not applicable - SQLite install | |
| 89 | MySQL | RAM Total/Usage | N/A | Not applicable - SQLite install | |
| 90 | MySQL | MySQL OS Last Update | N/A | Not applicable - SQLite install | |
| 91 | MySQL | MySQL Version | N/A | Not applicable - SQLite install | |
| 92 | MySQL | Repository access | N/A | Not applicable - SQLite install | |
| 93 | MySQL | Time sync | N/A | Not applicable - SQLite install | |
| 94 | Header | IceWarp Version | FULL | icewarp/version.sh -> icewarp.version | |
| 95 | Header | Antispam Last Update | FULL | icewarp/antispam.sh | |
| 96 | Header | Antivirus Last Update | FULL | icewarp/antivirus.sh | |
| 97 | Header | Last Backup Date and Time | FULL | icewarp/backup.sh -> icewarp.backup.last_time | <2d PASS, 2-7d WARN, >7d CRITICAL |
| 98 | Header | IceWarp Expiration Date | FULL | icewarp/license.sh -> icewarp.license.days_left | Handles Trial, Perpetual, SaaS |
| 99 | Header | SSL Expiration Date | FULL | icewarp/certificate.sh -> icewarp.ssl.expiration | Now live-verified via openssl |

---

## New Items Added During Development (beyond original 99)

These items were added based on the IceWarp 14.3.0.12 API and are evaluated in the reports.

| # | Section | Item | Status | Collector / Key | Notes |
|---|---------|------|--------|-----------------|-------|
| 100 | Backup | Enable Database Backup - AntiSpam | FULL | backup.db.as.enabled | Separated from Accounts |
| 101 | Backup | Enable Database Backup - GroupWare | FULL | backup.db.gw.enabled | Separated from Accounts |
| 102 | Backup | Enable Database Backup - Directory Cache | FULL | backup.db.cache.enabled | Optional (INFO) |
| 103 | Backup | Backup Emails | FULL | backup.emails.enabled | KIND=Z (0=WARN) |
| 104 | Watchdog | Watchdog - SMTP | FULL | watchdog.smtp | Individual service |
| 105 | Watchdog | Watchdog - POP3/IMAP | FULL | watchdog.pop3 | Individual service |
| 106 | Watchdog | Watchdog - IM/VoIP | FULL | watchdog.im | Individual service |
| 107 | Watchdog | Watchdog - GroupWare | FULL | watchdog.gw | Individual service |
| 108 | Watchdog | Watchdog Interval | FULL | watchdog.interval_minutes | 0-60 PASS, 61-1440 WARN |
| 109 | Watchdog | Remote Server Watchdog | FULL | watchdog.remoteserver.enable | INFO display |
| 110 | Archive | Archive Backup (Deleted Messages) | FULL | archive.backup.active | |
| 111 | System | Swap Usage (7 days) | FULL | system.swap.status | CRITICAL if any swap used in last 7 days |
| 112 | License | License Type | FULL | icewarp.license.type | onpremise / cloud / saas |
| 113 | License | License Status | FULL | icewarp.license.status | ok / expired / none |
| 114 | License | License Suite Type | FULL | icewarp.license.suite | pro / standard / lite |
| 115 | SMTP | Maximum Incoming Connections | FULL | smtp.max_incoming_connections | INFO display |
| 116 | SMTP | Maximum Outgoing Connections | FULL | smtp.max_outgoing_connections | INFO display |
| 117 | SMTP | Max Hop Count | FULL | smtp.max_hop_count | INFO display |
| 118 | SMTP | Max Client Recipients | FULL | smtp.max_client_recipients | INFO display |
| 119 | SMTP | Max Server Recipients | FULL | smtp.max_server_recipients | INFO display |

---

## Summary

| Category | Count |
|----------|-------|
| FULL (complete & evaluated) | 91 |
| PARTIAL (collected, review pending) | 0 |
| N/A (not applicable to SQLite) | 8 |
| MISSING | 0 |
| **Total original (1-99)** | **99** |
| **New items added (100-119)** | **20** |
| **Grand Total** | **119** |

### N/A Items (8)

The 8 items marked N/A (items 83, 86-93) are the remote MySQL server block. They are not missing - they simply don't apply to this IceWarp installation, which uses SQLite for the accounts database. The agent correctly detects this (via `database.type=sqlite`) and skips them.

If you ever migrate to MySQL, the agent will automatically detect it and those items will start being evaluated.
