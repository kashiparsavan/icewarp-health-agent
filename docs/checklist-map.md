# IceWarp Checklist Mapping

Legend: ✅ collected via tool.sh property (verified in tool.help) | 🟡 collected, OS/config fallback (needs verification on real server) | ❌ not implemented yet | ⚠️ implemented but property/syntax unverified - test on lab server

## General Information

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| Company name | icewarp/company.sh | 🟡 | Manual value, set `COMPANY_NAME` in agent.conf |
| Date | general/date.sh | ✅ | |
| Technician | - | ❌ | Likely manual/report-time field, not a system value |
| IceWarp Version | icewarp/version.sh | ✅ | C_Version |
| Antispam Last Update | icewarp/antispam.sh | 🟡 | No tool.sh property found; file mtime fallback |
| Antivirus Last Update | icewarp/antivirus.sh | 🟡 | No tool.sh property found; file mtime fallback |
| Last Backup Date and Time | icewarp/backup.sh | 🟡 | Filesystem mtime + C_System_Tools_AutoBackup_* |
| IceWarp Expiration Date | icewarp/license.sh | ✅ | C_LicenseStatus / C_License_Type / C_License_TrialExpire |
| SSL Expiration Date | icewarp/certificate.sh | 🟡 | openssl on configured cert path (IW_SSL_CERT) |

## Mail Server Checks

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| Check PTR | dns/ptr.sh | 🟡 | live `dig -x`, needs MAIL_PUBLIC_IP |
| Check SPF | dns/spf.sh | 🟡 | live `dig TXT` |
| Check DKIM | dns/dkim.sh | ⚠️ | domain-scoped tool.sh syntax unverified + DNS fallback |
| Check DMARC | dns/dmarc.sh | 🟡 | live `dig TXT _dmarc.<domain>` |
| Check TLS & StartTLS | dns/starttls.sh | 🟡 | live openssl s_client handshake |
| Check DNS Server | dns/dns_server.sh | ✅ | C_Mail_SMTP_General_DNSServer + live lookup test |
| Enable Logging - Auth/Maintenance | logging/sql_auth_log.sh | ✅ | C_Accounts_Global_Accounts_AuthLog / MaintenanceLog |
| Enable MailFlow Log | logging/mailqueue.sh | ✅ | C_System_Log_MailQueue (already existed) |
| Enable SQL Failed Logs | logging/sql_auth_log.sh | ✅ | C_System_SQLLogType |
| Daily Send Email limit | - | ❌ | Found only at account/domain level (U_NumberSendLimit / D_NumberLimit), no global property |
| Block outgoing port 9001 | - | ❌ | Needs firewall rule check (iptables/firewalld), not yet implemented |
| Enable System Backup | icewarp/backup.sh | ✅ | C_System_Tools_AutoBackup_Enable |
| Enable Database Backup | icewarp/backup.sh | 🟡 | covered generically by AutoBackup; no separate "DB only" flag found |
| Configure Archive Backup Settings | icewarp/backup.sh | 🟡 | partial - directory only, retention/schedule TBD |
| Enable System Watchdog | icewarp/watchdog.sh | ✅ | C_System_Tools_WatchDog_SMTP/POP3 |
| Enable System Monitor / Mem/Disk/CPU thresholds | os/cpu.sh, os/memory.sh, storage/storage.sh | 🟡 | raw values collected; threshold *rules* (4GB/100GB/50%) belong in M5 (Health Rules), not collectors |
| Check for Storage Locations | icewarp/storage_paths.sh | ✅ | renamed from icewarp/storage.sh |
| Check for Certificates | icewarp/certificate.sh | 🟡 | see above |
| RBL Valli Check | - | ❌ | No verified property found yet - needs more tool.help exploration |
| Enable Full Text Search Services | fulltext/scanner_queue.sh | ✅ | C_System_Services_Fulltext_Scanner_Queues |
| Reject if SMTP AUTH different from sender | mailserver/reject_auth_mismatch.sh | ✅ | C_Mail_Security_Protection_RejectSMTPAuthSender |
| 2FA | security/login_policy.sh | 🟡 | only global bypass-list flag found; per-domain 2FA needs domain iteration |
| Test DNS Lookup | dns/dns_server.sh | ✅ | live test |
| Max Message Size | smtp/max_message_size.sh | ✅ | C_Mail_SMTP_Delivery_MaxMsgSize |
| Use TLS/SSL (Secured Delivery) | mailserver/tls_ssl.sh | ✅ | C_Mail_SMTP_Delivery_UseTLSSSL |
| Process Incoming Messages in MDA Queue | mailserver/mda_queue.sh | ✅ | C_Mail_SMTP_Delivery_UseIncomingQueue |
| Use MDA Queue for Internal Delivery | mailserver/mda_queue.sh | ✅ | C_Mail_SMTP_Delivery_MDAInternal |
| Maximum Number of Simultaneous Threads | smtp/max_connections.sh | ✅ | C_System_Services_SMTP_ThreadCache (renamed from ambiguous old collector) |
| Hide IP Address from Received | mailserver/hide_ip.sh | ✅ | C_Mail_SMTP_Delivery_HideIP |
| Require HELO/EHLO | - | ❌ | No matching property found yet |
| Add Return-Path to All Messages | mailserver/rdns_returnpath.sh | ✅ | C_Mail_SMTP_Delivery_ReturnPath |
| Dedupe Email Messages | mailserver/dedupe.sh | ✅ | C_Mail_SMTP_Other_Dedupe |
| Relay Only if Originator's Domain is Local | smtp/relay.sh | ✅ | C_Mail_Security_Protection_LocalDomain |
| Process SMTP / POP3/IMAP | mailserver/process_protocols.sh | ✅ | C_Mail_SMTP_Active / C_Mail_IMAP_Active / C_Mail_POP_Active |
| Block IP - connections in 1 minute | smtp/parallel_ip_limit.sh | ✅ | (already existed) C_Mail_SMTP_General_ParallelIPConnectionsLimit |
| Set Directory Cache Schedule | - | ❌ | C_Accounts_Global_Accounts_DirectoryCacheSchedule found, type "Schedule" - needs format research |
| Hide Server Version | mailserver/hide_ip.sh | ✅ | C_Mail_SMTP_Delivery_HideServerVersion |
| Change Admin URL/Port | - | ❌ | Not located yet |

## Security / Anti-Spam (partial - large section, more to do)

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| Disable VRFY | mailserver/process_protocols.sh | ✅ | C_Mail_Security_Protocols_DenyVRFY |
| Whitelist trusted/local IPs and domains | security/antispam_policy.sh | ✅ | C_AS_BypassLocalIPs / BypassLocalDomains |
| Antispam mode / thread pool | security/antispam_policy.sh | ✅ | C_AS_General_AntispamMode / SpamMaxThreads |
| Block IP (failed logins) | security/login_policy.sh | ✅ | C_Accounts_Policies_Login_Attempts/BlockPeriod |
| Use DNSBL / IP Reputation / RBL blocking thresholds | - | ❌ | Not located yet - needs dedicated tool.help search |
| Archive Active | icewarp/archive.sh | ✅ | C_System_Tools_AutoArchive_Enable - implemented since this table was last edited, see appendix below |
| Password Policy | - | ❌ | TBD - separate password-policy property group exists in tool.help, not yet mapped |
| Disable DIGEST-MD5 | - | ❌ | Not located in available reference subset |
| Disable IMAP/POP3 | mailserver/process_protocols.sh | ✅ | same Active flags, inverse reading |
| Session Timeout | - | ❌ | Not located yet |

## Application Server / MySQL Server

Not started - these checks target a *different* host (the app/MySQL server, not the IceWarp box), so they need a remote-execution strategy (SSH key, separate config block) before collectors can even be written. Flagging for a design discussion before coding.

---
_This table replaces the previous draft version. Anything marked 🟡 or ⚠️ should be run once on the lab server and corrected if the property name, path, or CLI syntax turns out to be wrong._

---

## Appendix: collectors implemented but not yet mapped to a checklist row

26 collectors exist in the codebase that were never added to the tables above
(they were written across sessions and this doc fell behind). They are all
real, working, tested collectors — just not yet cross-referenced against the
original checklist item names. Re-mapping these against the source checklist
document is a remaining M5 documentation task; for now, here's what each one
actually collects (auto-generated from source, 2026-07-11):

| Collector | Purpose | Keys produced |
|---|---|---|
| general/os.sh | OS name/version detection | `general.os.*` |
| general/version.sh | IceWarp version (general-info duplicate of icewarp/version.sh) | `general.icewarp.version` |
| icewarp/env.sh | Base install paths / tool.sh presence | `icewarp.home`, `icewarp.installed`, `icewarp.tool*`, default path fields |
| icewarp/archive.sh | Archive settings (active, retention, IMAP integration, archive backup) | `archive.*` |
| icewarp/admin_access.sh | WebAdmin URL / dedicated port change detection | `admin.*` |
| icewarp/database_type.sh | SQLite vs local/remote MySQL detection (gates the MySQL Server section) | `database.*` |
| icewarp/directory_cache.sh | Directory cache schedule (raw only - format not decoded yet) | `directory_cache.*` |
| icewarp/domain_limits.sh | Per-domain send/quota limits, iterates all real domains | `domain.*` |
| icewarp/protocol_advanced.sh | Daytime clock sync, DIGEST-MD5 detection via auth scheme list | `icewarp.daytime_clock_sync.enabled`, `security.digest_md5.enabled` |
| icewarp/system_monitor.sh | IceWarp's own System Monitor alert thresholds (mem/disk/CPU) - now consumed directly by `lib/health.sh` | `monitor.*` |
| icewarp/watchdog_extra.sh | Watchdog services beyond SMTP/POP3 (IM, GW, Control, interval) | `watchdog.*` |
| http/port.sh, http/max_connections.sh | WebAdmin HTTP port/connections (⚠️ config-file key names unverified) | `http.port`, `http.max_connections` |
| mailserver/security_advanced.sh | Require HELO/EHLO, greeting delay, global POP-before-SMTP | `smtp.require_helo_ehlo`, `smtp.greeting_delay_seconds`, `smtp.global_pop_before_smtp` |
| mailserver/smtp_limits.sh | Hop count, recipient limits, per-domain throttling, header/footer, fulltext endpoint | `smtp.max_hop_count`, `smtp.max_*_recipients`, `smtp.max_per_domain_*`, `fulltext.enabled` |
| os/memory.sh | RAM/swap from /proc/meminfo | `os.memory.*`, `os.swap.*` |
| queue/incoming_queue.sh, queue/incoming_queue_enabled.sh, queue/no_retry.sh | SMTP incoming queue size/enabled/no-retry flag | `queue.smtp.*` |
| security/dnsbl_rdns.sh | DNSBL use, reverse-DNS/MX rejection rules, IP reputation | `security.dnsbl.*`, `security.reject_*`, `security.ip_reputation.use` |
| security/intrusion_prevention.sh | Full "Block IP that..." rule set (failed logins, relay denials, spam score, etc.) | `security.intrusion.*` (23 keys) |
| security/login_policy_mode.sh | Login policy mode (companion to login_policy.sh) | `security.login.block_mode` |
| security/password_policy.sh | Full password policy (length, complexity, expiration) - now evaluated by `lib/health.sh` | `security.password_policy.*` |
| smtp/max_incoming_connections.sh, smtp/max_outgoing_connections.sh | SMTP connection ceilings | `smtp.max_incoming_connections`, `smtp.max_outgoing_connections` |
| smtp/relay_server.sh | Configured relay server (companion to smtp/relay.sh) | `smtp.relay.server` |
| storage/storage.sh | Per-mount disk usage (install/mail/archive/root) - now evaluated by `lib/health.sh` | `storage.*.free_gb`, `.used_percent`, etc. |

**Corrected checklist tally as of 2026-07-11** (counting only the tables above,
not the appendix): 31 ✅ fully verified, 16 🟡 collected via fallback, 3 ⚠️
unverified syntax, 13 ❌ not yet found — 63 checklist rows tracked so far
against the original ~110-item document. The appendix adds ~26 more collectors
that already work but haven't been cross-referenced against checklist item
names yet.
