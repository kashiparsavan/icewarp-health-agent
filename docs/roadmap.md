# Roadmap

Last updated: 2026-09-23 (v0.4.0)

## Current State

| Milestone | Status | Notes |
|---|---|---|
| M1 - Framework and Core Architecture | 100% | agent.sh, locking, dynamic discovery, status tracking |
| M1.5 - Storage Architecture | 100% | storage_paths.sh and storage.sh |
| M2 - IceWarp Core Collectors | 100% | Version, license, database, services, backup, certificate, antispam, antivirus |
| M3 - Mail Server and Advanced Checks | 100% | All SMTP, DNS, security, logging, watchdog, archive, backup collectors |
| M4 - JSON and Transport | 70% | JSON solid, transport implemented but not validated against a real endpoint |
| M5 - Health Rules and Reports | 95% | health.sh, pdf.sh, management_report.sh all working |

## What Was Done in v0.4.0

- Complete rewrite of health.sh with correct logic for all checklist items.
- Added management_report.sh (non-technical PDF).
- Split Backup, Database Backup, Archive, and Watchdog into separate items.
- Fixed Logging KIND (changed from B to L). Was producing false CRITICAL.
- Fixed Backup keys (c_system_tools_autobackup_* and c_system_tools_backup_db_*).
- Fixed VRFY (c_mail_security_protocols_denyvrfy) and DIGEST-MD5 (c_auth_schemes).
- Fixed Cloud Features polarity (KIND changed from R to D).
- Added License evaluation with c_evalexpirationtime. Handles On-Premise, SaaS, and Cloud.
- Percentage-based Memory, Disk, and CPU thresholds.
- OS Update time-based thresholds.
- Swap monitoring (7-day history).
- Removed bc dependency. Using awk only.
- All core files have English section banners.

## Remaining Work

### High Priority

1. Transport validation: send_json has never been tested against a real
   monitoring endpoint. Needs retry and backoff logic.
2. License on SaaS: already handled. Needs verification on a second SaaS
   server.
3. Documentation sync: completed in v0.4.0.

### Medium Priority

4. Remote DB (MySQL): checklist items for remote DB are not implemented.
   Requires a remote-execution strategy.
5. License seat count: not available via tool.sh. Requires the Admin API
   or a database query.
6. X-Version header removal: not possible via native IceWarp configuration.
   Documented as a known limitation.

### Low Priority

7. HTTP collectors verification: webserver.dat key names need lab-server
   validation.
8. Full-text search verification: KIND=P logic works but has not been
   tested with a real enabled instance.

## Version History

| Version | Date | Highlights |
|---|---|---|
| 0.4.0 | 2026-09-23 | Complete overhaul of health rules, management report, license, backup, archive, watchdog |
| 0.3.0 | 2026-07-11 | Initial Health Rules and PDF writer |
| 0.2.0 | 2026-06-28 | Storage refactor |
| 0.1.0 | 2026-06-15 | Initial framework |
