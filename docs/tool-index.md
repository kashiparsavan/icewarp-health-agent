# IceWarp tool.sh Property Index

Reference of IceWarp tool.sh properties used by the collectors.
Last updated: 2026-09-23 (v0.4.0)

## General

| Property | Description | Used By |
|---|---|---|
| c_version | IceWarp version | icewarp/version.sh |
| c_suitetype | Suite type (1=pro, 2=standard, 3=lite) | icewarp/license.sh |
| c_license_type | License type (onpremise, cloud, saas) | icewarp/license.sh |
| c_licensestatus | License status code | icewarp/license.sh |
| c_evalexpirationtime | Evaluation expiration (Unix timestamp) | icewarp/license.sh |
| c_license_trialexpire | Trial expiration date (read-only) | icewarp/license.sh |
| c_os | OS type (0=Windows, 1=Linux) | general/os.sh |

## DNS

| Property | Description | Used By |
|---|---|---|
| c_dns_server | Configured DNS servers | dns/dns_server.sh |

## SMTP

| Property | Description | Used By |
|---|---|---|
| c_mail_smtp_use_tls_ssl | TLS and SSL delivery | mailserver/tls_ssl.sh |
| c_mail_smtp_hide_ip | Hide IP in Received header | mailserver/hide_ip.sh |
| c_mail_smtp_hide_server_version | Hide server version | mailserver/hide_ip.sh |
| c_mail_smtp_require_helo_ehlo | Require HELO and EHLO | mailserver/security_advanced.sh |
| c_mail_smtp_add_return_path | Add Return-Path header | mailserver/rdns_returnpath.sh |
| c_mail_smtp_dedupe | Deduplication | mailserver/dedupe.sh |
| c_mail_smtp_relay_local_domain_only | Relay local only | smtp/relay.sh |
| c_mail_smtp_mda_internal_delivery | MDA internal delivery | mailserver/mda_queue.sh |
| c_mail_smtp_incoming_queue_threads | Max threads | smtp/max_connections.sh |
| c_mail_smtp_max_message_size_mb | Max message size | smtp/max_message_size.sh |
| c_mail_smtp_delivery_reports_enabled | Delivery reports | mailserver/smtp_limits.sh |

## Logging

| Property | Description | Used By |
|---|---|---|
| c_accounts_authlog | Auth logging level | logging/auth_log.sh |
| c_accounts_maintenancelog | Maintenance log level | logging/maintenance_log.sh |
| c_system_log_mailqueue | Mail flow log level | logging/mailqueue.sh |
| c_system_sqllogtype | SQL log type | logging/sql_failed_log.sh |

## Backup

| Property | Description | Used By |
|---|---|---|
| c_system_tools_autobackup_enable | Auto backup enabled | icewarp/backup.sh |
| c_system_tools_autobackup_backupto | Backup target path | icewarp/backup.sh |
| c_system_tools_autobackup_deleteafter | Delete after days | icewarp/backup.sh |
| c_system_tools_backup_emails | Backup emails | icewarp/backup.sh |
| c_system_tools_backup_db_accountsenabled | Accounts DB backup | icewarp/database_backup.sh |
| c_system_tools_backup_db_accounts | Accounts DB DSN | icewarp/database_backup.sh |
| c_system_tools_backup_db_asenabled | Anti-Spam DB backup | icewarp/database_backup.sh |
| c_system_tools_backup_db_as | Anti-Spam DB DSN | icewarp/database_backup.sh |
| c_system_tools_backup_db_gwenabled | GroupWare DB backup | icewarp/database_backup.sh |
| c_system_tools_backup_db_gw | GroupWare DB DSN | icewarp/database_backup.sh |
| c_system_tools_backup_db_directorycacheenabled | Directory Cache DB backup | icewarp/database_backup.sh |
| c_system_tools_backup_db_directorycache | Directory Cache DSN | icewarp/database_backup.sh |

## Archive

| Property | Description | Used By |
|---|---|---|
| c_system_tools_autoarchive_enable | Archive active | icewarp/backup.sh |
| c_system_tools_autoarchive_path | Archive directory | icewarp/backup.sh |
| c_system_tools_autoarchive_imaparchive | IMAP integration | icewarp/backup.sh |
| c_system_tools_autoarchive_donotspam | Do not archive spam | icewarp/backup.sh |
| c_system_tools_autoarchive_backup_active | Backup deleted messages | icewarp/backup.sh |

## Watchdog

| Property | Description | Used By |
|---|---|---|
| c_watchdog_control | Main watchdog control | icewarp/watchdog.sh |
| c_watchdog_smtp | SMTP watchdog | icewarp/watchdog.sh |
| c_watchdog_pop3 | POP3 and IMAP watchdog | icewarp/watchdog.sh |
| c_watchdog_im | IM and VoIP watchdog | icewarp/watchdog.sh |
| c_watchdog_gw | GroupWare watchdog | icewarp/watchdog.sh |
| c_watchdog_interval | Watchdog interval (minutes) | icewarp/watchdog.sh |
| c_system_tools_remoteserver_enable | Remote server watchdog | icewarp/watchdog.sh |

## Security

| Property | Description | Used By |
|---|---|---|
| c_mail_security_protocols_denyvrfy | Disable VRFY | security/vrfy.sh |
| c_auth_schemes | Auth schemes list | security/digest_md5.sh |
| c_cloud_api_autoconfigure | Cloud features | security/cloud_features.sh |
| c_mail_security_tarpit_* | Intrusion Prevention (many keys) | security/intrusion_prevention.sh |
| c_mail_security_dnsbl_* | DNSBL settings | security/dnsbl_rdns.sh |
| c_mail_security_ipreputation_* | IP Reputation | security/dnsbl_rdns.sh |
| c_security_password_policy_* | Password policy | security/password_policy.sh |
| c_security_login_2fa_* | 2FA settings | security/login_policy.sh |

## Monitoring

| Property | Description | Used By |
|---|---|---|
| c_monitor_enabled | System Monitor | icewarp/system_monitor.sh |
| c_monitor_cpu_threshold_percent | CPU threshold | icewarp/system_monitor.sh |
| c_monitor_memory_alert_below_kb | RAM threshold | icewarp/system_monitor.sh |
| c_monitor_disk_alert_below_mb | Disk threshold | icewarp/system_monitor.sh |
| monitor_alert_email | Alert email | icewarp/system_monitor.sh |

## Web Service

| Property | Description | Used By |
|---|---|---|
| c_webservice_customhttpincludetext | Custom text appended to Server header | Not used in evaluation |
| c_webservice_security_enable_hsts | Enable HSTS | Not used in evaluation |

## Paths

| Property | Description | Used By |
|---|---|---|
| c_mail_default | Mail storage path | icewarp/storage_paths.sh |
| c_archive_default | Archive directory | icewarp/storage_paths.sh |
| c_backup_default | Backup directory | icewarp/storage_paths.sh |

