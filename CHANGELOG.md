# Changelog - IceWarp Health Agent

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/).

## [0.4.0] - 2026-09-23

### Major Overhaul

This release consolidates several months of development work. All main
checklist sections are now fully implemented and evaluated.

### Added

- Management report (`lib/management_report.sh`): non-technical PDF with
  visual status grid.
- License evaluation: uses `c_evalexpirationtime`, `c_licensestatus`, and
  `c_license_type`. Handles On-Premise Evaluation, Perpetual, and SaaS
  and Cloud correctly.
- Backup database checks: 4 separate items (Accounts, AntiSpam,
  GroupWare, Directory Cache).
- Archive Settings section: 5 dedicated items (Active, Directory, IMAP
  integration, Do Not Archive Spam, Backup Deleted Messages).
- Watchdog per-service: 4 individual services (SMTP, POP3/IMAP, IM/VoIP,
  GroupWare) plus main control and interval.
- Swap monitoring: checks swap usage in the last 7 days.
- OS Update time-based thresholds: under 7 days PASS, 7 to 30 days WARN,
  over 30 days CRITICAL.
- Intrusion Prevention validation: numeric values compared against
  expected defaults (10, 5, 5, 5, 9.00, 5, 30).
- File section indexing: all core files now have English section banners
  for easier maintenance.

### Fixed

- Logging (KIND changed from B to L): non-zero log level means PASS, zero
  means CRITICAL. Previously all logging items were false-CRITICAL.
- Backup key confusion: `icewarp.backup.auto_enabled` (main) versus
  `icewarp.database_backup.enabled` (database) resolved. Uses correct
  `c_system_tools_autobackup_*` keys.
- VRFY key: now uses `c_mail_security_protocols_denyvrfy`.
- DIGEST-MD5: now checks presence in `c_auth_schemes`.
- Cloud Features polarity: disabled means PASS, enabled means WARN. Was
  incorrectly CRITICAL before.
- Archive settings: uses `c_system_tools_autoarchive_*` keys.
- Health Summary filtering: only 8 key categories appear in the cover
  summary.

### Changed

- Memory, Disk, and CPU evaluation: percentage-based instead of
  absolute thresholds.
- Backup Last Time: separate item with PASS, WARN, or CRITICAL based on
  age (under 2 days, 2 to 7 days, over 7 days).
- Directory Cache Schedule: reports CRITICAL if not configured.
- `bc` dependency removed: all comparisons use `awk`.
- All Persian comments removed from code. English only.

### Removed

- Redundant "Process Incoming Messages in MDA Queue" merged with MDA
  Internal Delivery.

## [0.3.0] - 2026-07-11

### Added

- Initial Health Rules engine (`lib/health.sh`).
- PDF report writer (`lib/pdf.sh`).
- 60+ collectors across 12 categories.
- JSON exporter.
- First audit of checklist versus collectors.

### Known Issues at Release

- License not fully tested.
- Backup keys partially confusing.
- No management report yet.

## [0.2.0] - 2026-06-28

### Added

- Storage architecture refactor.
- Initial collectors for IceWarp core (version, license, database,
  services).
- Config fallback logic (`iw_get`).

## [0.1.0] - 2026-06-15

### Added

- Initial framework (`agent.sh`).
- Dynamic collector discovery.
- Locking mechanism.
- Base utility functions (`lib/common.sh`).
