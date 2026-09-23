# IceWarp Checklist Mapping

Legend:
- Collected via tool.sh property (verified)
- Collected via config or OS fallback
- Not implemented
- Syntax unverified

Last updated: 2026-09-23 (v0.4.0)

## General Information

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| Company name | CLI parameter or `icewarp/company.sh` | OK | via `--company` flag or `COMPANY_NAME` in agent.conf |
| Date | `general/date.sh` | OK | |
| Technician | CLI parameter | OK | via `--technician` flag |
| IceWarp Version | `icewarp/version.sh` | OK | `c_version` |
| Antispam Last Update | `icewarp/antispam.sh` | Fallback | file mtime |
| Antivirus Last Update | `icewarp/antivirus.sh` | Fallback | file mtime |
| Last Backup Date and Time | `icewarp/backup.sh` | OK | filesystem mtime |
| IceWarp Expiration Date | `icewarp/license.sh` | OK | `c_evalexpirationtime` for Trial and Evaluation |
| SSL Expiration Date | `icewarp/certificate.sh` | Fallback | openssl on `IW_SSL_CERT` |

## DNS and Mail Flow

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| Check PTR | `dns/ptr.sh` | OK | needs `MAIL_PUBLIC_IP` |
| Check SPF | `dns/spf.sh` | OK | live dig TXT |
| Check DKIM | `dns/dkim.sh` | OK | multi-selector DNS fallback |
| Check DMARC | `dns/dmarc.sh` | OK | live dig TXT _dmarc |
| Check TLS and StartTLS | `dns/starttls.sh` | OK | live openssl |
| Check DNS Server | `dns/dns_server.sh` | OK | c_mail_smtp_general_dnsserver |
| Test DNS Lookup | `dns/dns_server.sh` | OK | live test |
| Resolver External Test | `dns/resolver_external.sh` | OK | Google and Cloudflare test |

## Logging

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| Enable Logging - Auth | `logging/auth_log.sh` | OK | KIND=L |
| Enable Logging - Maintenance | `logging/maintenance_log.sh` | OK | KIND=L |
| Enable MailFlow Log | `logging/mailqueue.sh` | OK | KIND=L |
| Enable SQL Failed Logs | `logging/sql_failed_log.sh` | OK | KIND=L |

## Backup, Watchdog and Monitoring

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| Enable System Backup | `icewarp/backup.sh` | OK | c_system_tools_autobackup_enable |
| Enable Database Backup - Accounts | `icewarp/database_backup.sh` | OK | c_system_tools_backup_db_accountsenabled |
| Enable Database Backup - AntiSpam | `icewarp/database_backup.sh` | OK | c_system_tools_backup_db_asenabled |
| Enable Database Backup - GroupWare | `icewarp/database_backup.sh` | OK | c_system_tools_backup_db_gwenabled |
| Enable Database Backup - Directory Cache | `icewarp/database_backup.sh` | OK | c_system_tools_backup_db_directorycacheenabled |
| Backup Emails | `icewarp/backup.sh` | OK | KIND=Z, disabled means WARN |
| Last Backup Date and Time | `icewarp/backup.sh` | OK | filesystem mtime |
| Enable System Watchdog | `icewarp/watchdog.sh` | OK | watchdog.control |
| Watchdog - SMTP | `icewarp/watchdog.sh` | OK | watchdog.smtp |
| Watchdog - POP3/IMAP | `icewarp/watchdog.sh` | OK | watchdog.pop3 |
| Watchdog - IM/VoIP | `icewarp/watchdog.sh` | OK | watchdog.im |
| Watchdog - GroupWare | `icewarp/watchdog.sh` | OK | watchdog.gw |
| Watchdog Interval | `icewarp/watchdog.sh` | OK | watchdog.interval_minutes |
| Enable System Monitor | `icewarp/system_monitor.sh` | OK | monitor.enabled |
| Remote Server Watchdog | `icewarp/watchdog.sh` | OK | KIND=V (INFO) |

## Storage, Certificates and Services

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| Check for Storage Locations | `icewarp/storage_paths.sh` | OK | |
| Check for Certificates | `icewarp/certificate.sh` | OK | |
| RBL Valli Check | `security/rbl_self_check.sh` | OK | live DNS RBL query |
| Enable Full Text Search | `fulltext/scanner_queue.sh` | OK | KIND=P |
| Reject if SMTP AUTH Different | `mailserver/reject_auth_mismatch.sh` | OK | |
| 2FA | `security/login_policy.sh` | OK | security.login.2fa_bypass_enabled |
| Daily Send Email limit | `icewarp/domain_limits.sh` | OK | KIND=Z |

## SMTP Delivery Settings

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| Max Message Size (MB) | `smtp/max_message_size.sh` | OK | |
| Delivery Reports | `mailserver/smtp_limits.sh` | OK | |
| Use TLS/SSL | `mailserver/tls_ssl.sh` | OK | |
| Process Incoming Messages in MDA Queue | `mailserver/mda_queue.sh` | OK | |
| Use MDA Queue for Internal Delivery | `mailserver/mda_queue.sh` | OK | |
| Maximum Simultaneous Threads | `smtp/max_connections.sh` | OK | Expected: 10 |
| Hide IP Address from Received | `mailserver/hide_ip.sh` | OK | |
| Hide Server Version | `mailserver/hide_ip.sh` | OK | |

## SMTP Protocol Hardening

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| Require HELO/EHLO | `mailserver/security_advanced.sh` | OK | |
| Add Return-Path | `mailserver/rdns_returnpath.sh` | OK | |
| Dedupe Email Messages | `mailserver/dedupe.sh` | OK | |
| Relay Only if Originator Local | `smtp/relay.sh` | OK | |
| Process SMTP | `mailserver/process_protocols.sh` | OK | |
| Process POP3/IMAP | `mailserver/process_protocols.sh` | OK | |
| Add rDNS Result to Received | `mailserver/rdns_returnpath.sh` | OK | |
| Set Directory Cache Schedule | `icewarp/directory_cache.sh` | OK | KIND=B, critical if not set |
| Change Admin URL | `icewarp/admin_access.sh` | OK | |

## Intrusion Prevention - Block Rules

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| Block IP - Connections per Minute | `security/intrusion_prevention.sh` | OK | Expected: 10 |
| Block IP - Unknown User Delivery | `security/intrusion_prevention.sh` | OK | Expected: 5 |
| Block IP - Denied for Relay | `security/intrusion_prevention.sh` | OK | Expected: 5 |
| Block IP - RSET Session Count | `security/intrusion_prevention.sh` | OK | Expected: 5 |
| Block IP - Spam Score | `security/intrusion_prevention.sh` | OK | Expected: 9.00 |
| Block IP - Failed Logins | `security/intrusion_prevention.sh` | OK | Expected: 5 |
| Block Duration | `security/intrusion_prevention.sh` | OK | Expected: 30 |
| Block IP - Listed on DNSBL | `security/intrusion_prevention.sh` | OK | |
| Refuse Blocked IP | `security/intrusion_prevention.sh` | OK | |
| Close Blocked Connection | `security/intrusion_prevention.sh` | OK | |
| Close All Other Connections | `security/intrusion_prevention.sh` | OK | |
| Cross Session Processing | `security/intrusion_prevention.sh` | OK | |

## Rejection Rules and Access

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| Use DNSBL | `security/dnsbl_rdns.sh` | OK | |
| Close Connections for DNSBL | `security/dnsbl_rdns.sh` | OK | |
| Use IP Reputation | `security/dnsbl_rdns.sh` | OK | |
| Reject if no rDNS | `security/dnsbl_rdns.sh` | OK | |
| Reject if Domain Does Not Exist | `security/dnsbl_rdns.sh` | OK | |
| Reject if Local and Not Authorized | `smtp/relay.sh` | OK | |
| Set customers-stat@parsavan.com | Custom | OK | expects monitor.alert_email |
| Disable AntiSpam Live | `security/antispam_live.sh` | OK | KIND=D |
| Remove Old AntiSpam Folders | `security/cyren_folder.sh` | OK | |
| Password Policy Min Length | `security/password_policy.sh` | OK | |
| Set Admin Email | Custom | OK | |
| Change Admin Port | `icewarp/admin_access.sh` | OK | |
| Block Outgoing Port 9001 | `security/port_9001.sh` | OK | firewalld check |

## Archive Settings

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| Archive Active | `icewarp/backup.sh` | OK | c_system_tools_autoarchive_enable |
| Archive to Directory | `icewarp/backup.sh` | OK | c_system_tools_autoarchive_path |
| Integrate Archive with IMAP | `icewarp/backup.sh` | OK | c_system_tools_autoarchive_imaparchive |
| Do Not Archive Spam | `icewarp/backup.sh` | OK | c_system_tools_autoarchive_donotspam |
| Archive Backup (Deleted Messages) | `icewarp/backup.sh` | OK | c_system_tools_autoarchive_backup_active |

## Protocol and Access Hardening

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| Disable VRFY | `security/vrfy.sh` | OK | c_mail_security_protocols_denyvrfy |
| Disable DIGEST-MD5 | `security/digest_md5.sh` | OK | checks c_auth_schemes, KIND=R |
| Session Timeout | `icewarp/protocol_advanced.sh` | OK | |
| Enable SSL/TLS | `mailserver/tls_ssl.sh` | OK | |
| Disable Cloud Features | `security/cloud_features.sh` | OK | KIND=D, 0 is PASS, 1 is WARN |
| Disable IMAP | `mailserver/process_protocols.sh` | OK | |
| Disable POP3 | `mailserver/process_protocols.sh` | OK | |

## APP OS and Infrastructure

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| APP OS Version | `general/os.sh` | OK | |
| Disk (Total and Used Percent) | `storage/storage.sh` | OK | WARN at 80 percent, CRITICAL at 95 percent |
| CPU Usage | `os/cpu.sh` | OK | 15-min load, WARN above 50, CRITICAL above 95 |
| RAM (Total and Available) | `os/memory.sh` | OK | WARN above 40, CRITICAL above 90 |
| APP OS Last Update | `os/os_update.sh` | OK | under 7d PASS, 7-30d WARN, over 30d CRITICAL |
| Repository Access | `os/repository_access.sh` | OK | |
| Time Sync (OS-level NTP) | `os/time_sync.sh` | OK | |
| Swap Usage (7 days) | `os/swap.sh` | OK | |

## Database

| Checklist Item | Collector | Status | Notes |
|---|---|---|---|
| Database Type | `icewarp/database_type.sh` | OK | sqlite is WARN, mysql is PASS |
| Database Scope | `icewarp/database_type.sh` | OK | |
| MySQL items | Not implemented | Pending | Remote DB requires separate strategy |

## MySQL Server (Remote DB)

Not implemented. Requires a remote-execution strategy (SSH or API).
Out of scope for v0.4.0.
