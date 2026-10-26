# Changelog - IceWarp Health Agent

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/).

## [windows-0.1.0] - 2026-10-26

### Added

- Independent Windows PowerShell 5.1 scaffold under `windows/` with its own
  `VERSION`, PSD1 configuration, logging, IceWarp `tool.exe` wrapper, flat JSON
  output, and collector runner.
- Windows JSON keeps native booleans and numbers and maps empty strings to
  `null`, matching the Linux JSON contract.
- `windows/collectors/General/Version.ps1` as the first sample collector.
- Pester smoke tests with a Pester 3.4/5-compatible runner.
- Windows setup, deployment, and troubleshooting documentation.

### Changed

- Added PowerShell line-ending rules and Windows runtime/config exclusions to
  `.gitattributes` and `.gitignore`.
- Added the Windows platform status and usage section to `README.md`.

### Notes

- The Linux agent and its auto-updater are unchanged. The Windows tree does not
  call `agent.sh` or source anything from the Linux `lib/` directory.
- Windows releases use independent `windows-v*` tags.
- The Windows scaffold is not feature parity: the full checklist, health rules,
  PDF reports, DNS collectors, and automatic updates are not ported yet.

## [0.6.0] - 2026-10-20

### Added

- Modern management report with a soft-cyberpunk dark cover, score arc,
  executive overview, control-area scorecards, stacked status bars, status
  key, management takeaway, and prioritized recommended actions.
- Management report evaluates all 113 checklist items while printing only
  management-level findings and display-friendly action labels.
- Nine-pillar technical Health Summary: Backup & Recovery, Mail Flow & DNS,
  Transport Security, Access & Authentication, Threat Protection, Server
  Resources, OS & Patching, Monitoring & Watchdog, and Database Platform.
- Grouped technical appendix tables. Raw keys are organized by subsystem,
  sorted, and rendered with repeating table headers on page breaks instead of
  a flat key dump.
- Running report name and page numbers on non-cover technical pages.
- `CHECKLIST_VERSION` setting in `config/agent.conf`; both PDFs reference
  IceWarp CheckList v1.14.
- Company fallback to the domain that carries mail when `--company` is omitted.
- Technician default `Parsavan` when `--technician` is omitted.

### Changed

- `VERSION` and `config/agent.conf` bumped to `0.6.0`.
- Technical report cover now shows Mail Domain and the v1.14 checklist label.
- Management distribution bar and legend include informational and N/A
  controls alongside healthy, review, and action; the score is labelled as a
  pass rate of scored controls.
- Technical section headers keep a minimum block of rows together to avoid
  orphan headers and near-empty pages; Collector Status no longer forces a new
  page.
- Appendix values use a darker, higher-contrast gray for small table text.
- README, CLAUDE.md, checklist coverage/map, roadmap, and update log updated
  for the report redesign and v1.14 label.

### Fixed

- Bash `local` initialization failures in management layout helpers under
  `set -u`.
- Management paragraph line-height arithmetic with decimal values.
- Malformed management score-arc stream output that produced literal `\n` and
  invalid path operators.
- Duplicate management cover footer.

### Notes

- v1.14 is an internal IceWarp checklist edition. The item set remains the
  existing v1.12-mapped 113-item set; only the displayed report version changed.
  No item-level v1.14 diff was available in the repository.

## [0.5.0] - 2026-10-19

### Added

- Automatic self-update before every agent invocation. The updater follows
  `origin/main` by default, fast-forwards only, and re-executes the agent so
  the current run uses the new code (`lib/auto_update.sh`).
- `--check-update` to report whether a newer revision is available without
  changing files.
- `--no-auto-update` to skip the update check for one run, and
  `--auto-update` to force a check when disabled in configuration.
- Append-only update audit log at `logs/auto_update.log`, with size-based
  rotation and credential redaction.
- Update lock (`.agent.update.lock`) to prevent concurrent Git operations.
- Normal runs hold `.agent.lock` across the update and re-exec; lock ownership
  is preserved by PID, so a second scheduled run cannot rewrite files under an
  active run.
- Pre-merge guards: checked-out branch, expected origin, clean tracked working
  tree, and fast-forward-only merge.
- Post-update `bash -n` validation of `agent.sh` and all shell scripts. A
  failed revision is automatically reverted to the previous commit.
- `docs/auto-update.md` and `docs/update-log.md` for operating and auditing
  automatic updates.

### Fixed

- Configurator property names now use canonical IceWarp v14.3 `tool.help`
  keys instead of guessed/legacy names. This removes the large number of
  `[SKIP] ... key not found` results during `./agent.sh --config`.
- Configurator key matching is case-insensitive and tolerates leading
  whitespace in `tool.sh display system` output.
- Configurator calls honor `TOOL_TIMEOUT` instead of a hardcoded 5 seconds.

### Changed

- `VERSION` and `config/agent.conf` bumped to `0.5.0`.
- `--no-update` remains a deprecated no-op; use `--no-auto-update` for agent
  updates.
- `maintenance/collectors_validity_checker.sh` disables auto-update during
  validation runs.

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
