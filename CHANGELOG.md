# Changelog - IceWarp Health Agent

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [0.7.2] - 2026-11-02

### Added

- `tests/` directory with a Bash test harness (`tests/run_tests.sh`, `tests/lib.sh`)
  and four cases: `test_norm_date.sh`, `test_json_value.sh`,
  `test_health_rollup.sh` and a fake-SMTP `test_starttls.sh`. Fixtures live in
  `tests/fixtures/`; `tests/render_pdfs.sh` renders both PDFs from a sample
  `DATA[]` and extracts their text for inspection.
- `## 2. CODE STYLE` and `## 3. TDD & Testing Conventions` sections to
  `CLAUDE.md` (write the failing test first, then the minimal fix).

### Fixed

- **Health label map (lib/health.sh).** `HEALTH_LABEL_MAP` now maps
  `Password Policy Min Length` -> `password_policy`, `Use TLS/SSL (Secured
  Delivery)` and `Enable SSL/TLS` -> `tls_delivery`, and `RBL Valli Check (is
  our IP blacklisted)` -> `threat.rbl`. Four rolled-up checks had no checklist
  row, so a pillar could read red with no matching action card: `config/checklist.conf.pdf`
  now carries a `Health Evaluation` section with rows for `login_blocking`,
  `threat.antispam`, `threat.antivirus` and `dnsbl_zones`, so every rolled-up
  check appears in both PDFs.
- **Management report counters (lib/management_report.sh).** `build_management_pdf`
  now resets `_MR_TOTAL/_MR_PASS/_MR_WARN/_MR_CRIT/_MR_INFO/_MR_NA/_MR_SECTION_ORDER/
  _MR_ISSUES/MR_SEC*` at its start, so a second build no longer doubles the
  counts. The overall posture and the cover score agree with
  `health.summary.overall` (worst of the health summary and the row-derived
  result); skipped and INFO-only checks are excluded from the denominator and
  never inflate the score.
- **Text fitting (lib/pdf.sh, lib/management_report.sh).** The technical report's
  Value column is truncated at 46 chars instead of 34, so
  `Total(KB)=<n> / Available KB=<n>` and `Total(GB)=<n> / Used %=<n>` are never
  cut. Health-summary notes are no longer clipped at 100 chars: they wrap to
  two lines, the note baseline is raised and the row height is 28 pt so
  descenders are not hidden. `_mr_paragraph` appends `...` when `MAXLINES`
  truncates and never emits an empty first line for an over-long word; cover
  company/domain text is truncated; the rounding remainder of both status bars
  is left as the muted track background instead of being painted as the
  INFO/N-A colour.
- **STARTTLS (collectors/dns/starttls.sh).** The probe now targets the real mail
  host: `MAIL_HOSTNAME`, else the primary domain's MX target, never just the
  first mail domain. The loopback message is cleaned so `lib/health.sh` no
  longer duplicates `via host:port`; `smtp.starttls.target` carries the host
  only. `smtp.starttls.trust` is recorded as `not verified` (the probe never
  validates the chain), and the health message states it. A wall-clock budget
  (`STARTTLS_BUDGET`, default 45 s) caps the total probe time.
- **Health semantics (lib/health.sh).** `2FA`, `watchdog.interval` and
  `monitor.enabled` now report `skip`/`warn` (never an invented `pass` or a
  default threshold) when their data key is missing. Disk de-duplication is
  deterministic: mounts are iterated in sorted key order and every comparison
  is numeric-safe. `health.summary.total_checks` counts evaluated registry
  checks (not pillars); `health.summary.areas_assessed` is the pillar count, so
  the cover text "X checks run across Y areas" is truthful.
- **JSON (lib/json.sh).** `*.name`, `*.company`, `*.technician` and license
  identifier keys are forced to strings (a numeric company name can no longer
  become a number). `health.json` is now written atomically via temp file +
  `mv`, so a monitoring client reading mid-write never sees a truncated
  document.
- **Transport (lib/transport.sh).** `MONITOR_URL` and the payload file are
  validated before posting; curl now takes `--connect-timeout`/`--max-time`,
  `--retry`/`--retry-delay` and an optional `MONITOR_AUTH_HEADER`; the curl
  exit status is returned and logged by `agent.sh`. Documented decision: the
  posted payload is `health.json` (v1, the flat namespace) - `health.v2.json`
  is a separate artifact and is not posted.

## [0.7.1] - 2026-11-01

Findings from the first live run of 0.7.0.

### Fixed

- STARTTLS false-fail (`collectors/dns/starttls.sh`): the probe ran once, with the shared 5 s
  `TOOL_TIMEOUT`, and counted success only when openssl printed "Verify return code". A server that
  answers slowly (IceWarp does reverse-DNS/DNSBL lookups per connection) was killed before the TLS
  summary and reported as "STARTTLS failed". Reproduced with a fake SMTP server whose banner is
  delayed 7 s: old collector `false`, new collector `true`. Now: `STARTTLS_TIMEOUT` (15 s), one retry,
  loopback fallback, strict success criterion (a real TLS session) and recorded evidence
  (`smtp.starttls.via|protocol|attempts|error|target`). `mail.starttls` is `warn` when only loopback
  works and `fail` with the reason when nothing works.
- PDF rows `Check PTR/SPF/DKIM/DMARC/TLS and Start TLS/Test DNS Lookup` and `Set customers-stat`
  now read their health check, so they agree with the Mail Flow / Access pillars (the PTR row said
  PASS while the pillar said WARN). New detail-only check `access.stats_mailbox`.
- Management report: Key Signals show the four worst pillars (the fixed set hid the CRITICAL
  Database pillar); Priority/Recommended actions list Action before Review.
- Swap collector: the 7-day journal search matched dracut/initramfs file listings
  (`swap.target`, `swapoff`) and reported "swap usage detected" on every kernel update. It now only
  matches real swap events; swap in use is still CRITICAL by policy.
- `disk.overall` carries the lowest free MB as `actual`; certificate display is
  `40 days left (2026-12-11)` instead of a truncated openssl date; messages read "Antispam
  definitions: 5 days old"; `smtp.hide_server_version` is a number, not the string `"1"`.

## [0.7.0] - 2026-11-01

### Added

- Check registry in `lib/health.sh` (`HEALTH_REGISTRY_LINES`): one line per check
  (`id|pillar|title|flags`). Pillar roll-ups, `health.v2.json` `checks[]` and the PDF/management
  statuses all derive from it. Every check now carries `pillar`, `expected` and `actual`.
- New checks (new `health.<id>.result|message` keys; no existing key removed or renamed):
  `intrusion.unknown_user|relay_denied|rset|spam_score|failed_logins` (expected 5/5/5/9.00/5),
  `tls.certificate`, `access.2fa`, `mail.spf|dkim|dmarc|ptr|starttls|dns_lookup`,
  `threat.antispam|antivirus|rbl|cyren`, `smtp.threads`, `swap`, `database.platform`.
- `health_row_for_label` / `health_kind` / `health_meta` / `health_rolled_up` helpers.
  `_health_set` takes a 6th `display` argument (the PDF "Value" column).

### Changed

- **Roll-ups now include** intrusion 50/360 and the five other intrusion rules (threat),
  IMAP/POP3 running (mail_flow), per-service watchdogs SMTP/POP3-IMAP/IM-VoIP/GroupWare
  (monitoring), Directory Cache schedule and database platform (database), TLS certificate expiry
  (tls) and 2FA bypass (access). They affect the pillar status, overall score and both PDFs.
  `backup.db.accounts|as|gw`, `backup.db.cache`, `smtp.threads` and `swap` stay detail-only.
- The PDF renderers no longer hold thresholds. `lib/pdf.sh` and `lib/management_report.sh` read the
  health result for every mapped checklist row (`HEALTH_LABEL_MAP`); about 650 lines of duplicated
  threshold code were removed. Where they disagreed, `health.sh` now wins: backup age (warn 2-6,
  critical 7+ days; PDFs used 4), certificate (30 days is now warn), CPU (System Monitor
  threshold on 1-min load; PDFs used 15-min load 50/95%), disk (System Monitor free-space floor;
  PDFs used 80/95% used), the management report no longer ignores `critical` in grouped rows.
- Pillar `database` is now `database.platform` + `directory_cache`; the check formerly named
  `database` is `database.platform` (the pillar keeps the id `database`).
- Directory Cache: an empty schedule value is "not scheduled" (CRITICAL), confirmed on the lab server.
- `collectors/security/dnsbl_zones.sh` reads `rbl.dat` first (IceWarp's DNSBL server list).
- `config/checklist.conf.pdf` notes no longer quote thresholds.
- `VERSION` and `config/agent.conf` bumped to `0.7.0`.

### Added

- `lib/json_v2.sh` / `build_json_v2`: writes `output/health.v2.json`, a versioned envelope
  (`schema_version`, `agent`, `server` with a persistent `.server_id` UUID, `run`, `summary`
  with the nine pillars and a 0-100 score, `checks[]` with `expected`/`actual`, typed `metrics`,
  and the unchanged flat keys under `raw`). Schema: `docs/schema/health.v2.schema.json`.
  `health.json` (v1) keeps its key set. Status vocabulary in v2: `ok|warn|crit|unknown`.
- `_health_set` accepts optional `expected` and `actual` arguments (used by the intrusion and
  password-policy checks); they only feed v2 and never enter `DATA[]`.
- New keys: `security.dnsbl.zones.source`, `directory_cache.schedule_source`.

### Changed

- JSON coercion (`lib/json.sh`) is strict: `007`/`00123` and numbers over 15 digits are strings
  (they were emitted as invalid JSON numbers), the literal `null` becomes JSON `null`, control
  characters are stripped, and `*version`/`*.ip`/`*.domain`/`*.hostname`/`*.host` keys are always
  strings (`general.os.version` `9.8` -> `"9.8"`, `icewarp.antispam.update_version` is always a string).
- `health.backup.db.cache.result` is `pass` (optional feature) instead of `info`.

### Fixed

- DNSBL zones: the collector read guessed `C_*` properties that do not exist, so every server
  reported "No DNSBL zones configured". It now scans the IceWarp config files for known zones and
  records the source; `health.sh` says "could not be read" when no config file is readable.
- Directory Cache schedule was always empty (single-field `awk` parse of a multi-field Schedule
  value). It is now read whole via `display`, then `get`, then the config files.

### Security

- DSN passwords are redacted at collection time (`redact_dsn`): `database.connection_string_raw`,
  `directory_cache.connection_string` and all `backup.db.*.target_dsn` now show
  `db;user;***;host;type;flag`. `lib/json.sh` re-applies the redaction to any key matching
  `*dsn*|*connection_string*` as a safety net. Real MySQL installs previously exposed the
  password in `health.json`, both PDFs and the monitoring POST.

### Fixed

- Date parsing: IceWarp `D-M-YY` strings (e.g. `27-10-26`) were fed to `date -d`, which read
  them as year 2027 / 2005 / 0009, producing false passes (future date) or false failures
  (thousands of days old). New shared `norm_date` / `_days_ago` in `lib/common.sh` (ISO, `D-M-YY`
  and `M/D/YYYY`); the three duplicate `_days_ago` copies are removed. Unparseable dates now
  give `warn`, never `0`/`999`.
- `icewarp.antispam.last_update` and `icewarp.antivirus.last_update` are now ISO `YYYY-MM-DD`
  (empty when never updated); the original string is kept in `*.last_update_raw`.
- `database.type` was `unknown` for MySQL DSNs whose host carries a port
  (`127.0.0.1:3306`), which also raised a false `health.database` warning.

### Added

- `tool.v14.3.0.13.help`, the IceWarp 14.3.0.13 Linux `APIConst.pas` API
  reference. The supplied Linux file is byte-identical to the Linux 14.3.0.12
  reference; no Linux API keys changed.
- `docs/api-update-v14.3.0.12-to-14.3.0.13.md` with the Linux comparison,
  Windows hash check, and verification commands.

### Changed

- `docs/checklist-coverage.md` now records that the Linux 14.3.0.13 API
  reference is unchanged, so the existing 113-item mapping still applies.
- `docs/api-update-v14.3.0.12-to-14.3.0.13.md` and `windows/README.md` now
  point to the Windows-vs-Linux comparison.

### Added

- `tool.v14.3.0.13.windows.help`, the IceWarp 14.3.0.13 Windows
  `APIConst.pas`. Kept alongside the Linux reference; the two files are not
  byte-identical.
- `docs/api-windows-vs-linux-v14.3.0.13.md` with the Windows-vs-Linux key,
  ID, type, description, and read-only comparison.

### Notes

- The Windows 14.3.0.13 `APIConst.pas` has a different SHA-256 from the Linux
  file. A key-level comparison has since been completed: all Linux keys are
  present on Windows, Windows adds 4 keys, and 2 keys differ in
  capitalization. No collector or checklist changes are required.

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
