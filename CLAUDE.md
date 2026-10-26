# CLAUDE.md

Guidance for Claude Code (and other AI agents) working in this repository.

## What this project is

**IceWarp Health Agent** is a dependency-free, Bash-based health-check and
reporting tool for IceWarp mail servers. It runs on the mail server, collects
data from `tool.sh`, OS commands, and DNS, evaluates the results against the
IceWarp Checklist (report label v1.14; item set still the v1.12-mapped 113
items), and produces:

- `output/health.json` — flat, type-aware JSON for monitoring systems
- `output/report.pdf` — full technical report
- `output/management_report.pdf` — non-technical executive summary

Linux version: **0.6.0** (`VERSION`, `config/agent.conf`). Windows scaffold
version: **0.1.0** (`windows/VERSION`). Linux target: RHEL/Rocky/AlmaLinux and
Debian/Ubuntu families with Bash 4+ and GNU coreutils. There is no runtime,
package manager, database, or web server.

A separate Windows implementation lives under `windows/` and targets Windows
PowerShell 5.1. It is independent: it does not call `agent.sh`, does not source
anything from the Linux `lib/`, and does not share Linux configuration. See
`windows/README.md`. Windows target: Windows Server 2012 R2 or later with
Windows PowerShell 5.1 and IceWarp `tool.exe`.

## Commands

Run from the repository root **on the IceWarp server** (normally as root):

```bash
./agent.sh                                  # full run: collect + evaluate + JSON + PDFs
./agent.sh --report                         # same, plus console summary
./agent.sh --list                           # list collectors
./agent.sh --only=dns,backup                # only collectors whose path contains a filter
./agent.sh --technician="Name" --company="Company"
./agent.sh --config                         # show recommended-config diff (dry run)
./agent.sh --config --apply                 # apply changes with tool.sh set system
./agent.sh --check-update                   # fetch and report update availability, then exit
./agent.sh --no-auto-update                 # skip self-update for this run
./agent.sh --auto-update                    # force a self-update check
./agent.sh --no-update                      # deprecated no-op
```

If `--technician` is omitted the report uses `Parsavan`. If `--company` is
omitted it uses `domain.primary.name`, then `MAIL_DOMAIN`, then the first
`tool.sh` domain, then `MAIL_HOSTNAME`.

Development / diagnostics (still Linux + IceWarp):

```bash
bash -n agent.sh lib/*.sh collectors/**/*.sh    # syntax check
./maintenance/collector_tester.sh <collector>   # run one collector, print DATA keys
./maintenance/collectors_validity_checker.sh    # run all collectors + validate health.json
./maintenance/collectors_validity_checker.sh --list
```

The Linux tree has no unit-test framework and no CI. A meaningful test requires
`/opt/icewarp/tool.sh` and a live IceWarp installation; on a plain dev machine
collectors will mostly return empty/skip values. Do not claim a runtime fix was
verified without exercising it on a lab server.

Windows commands (from the `windows/` directory, Windows PowerShell 5.1):

```powershell
.\agent.ps1                                  # collect + write output\health.json
.\agent.ps1 -Report                          # same, plus console summary
.\agent.ps1 -List                            # list collectors
.\agent.ps1 -Only General -Report            # filter by relative collector path
.\agent.ps1 -ConfigPath .\config\agent.local.psd1
.\tests\Run-Tests.ps1                        # Pester smoke tests
```

The Windows tests do not need a live IceWarp server. A live `tool.exe` is needed
to validate the actual IceWarp values.

## Architecture and data flow

```
agent.sh
  ├─ sources config/agent.conf and config/icewarp.conf
  ├─ sources lib/auto_update.sh → fetch origin/main, fast-forward, log
  │    └─ on update: re-exec agent.sh with AGENT_UPDATE_REEXEC=1
  ├─ sources lib/common.sh, health.sh, pdf.sh, json.sh,
  │  management_report.sh, transport.sh, configurator.sh
  ├─ find collectors -name '*.sh' | sort → source + collector_run() for each
  │    └─ collectors write flat dotted keys into DATA[]
  ├─ evaluate_health()  → HEALTH[] + health.<item>.result/.message in DATA[]
  ├─ build_json()       → output/health.json
  ├─ send_json()        → optional POST to $MONITOR_URL when SEND_DATA=1
  ├─ build_pdf()        → output/report.pdf
  └─ build_management_pdf() → output/management_report.pdf
```

The updater is the only code that runs before the normal library load. It
must remain self-contained: it cannot rely on `common.sh`, `DATA`, or any
collector helper.

Windows flow (independent):

```
windows/agent.ps1
  -> dot-sources windows/lib/Common.ps1, Logging.ps1, Config.ps1,
     IceWarpTool.ps1, Json.ps1
  -> loads config/agent.local.psd1, falling back to agent.example.psd1
  -> discovers collectors/**/*.ps1 in sorted order
  -> runs each collector in a child scope with -Context
  -> merges one ordered dictionary per collector into DATA
  -> writes output/health.json and logs/agent.log
```

Windows collectors must not call the Linux entry point or libraries. The
Windows data contract is flat dotted keys, matching the Linux names where a
collector is ported. Windows JSON keeps native booleans and numbers and maps
empty strings to `null`.

Key implementation details:

- **Auto-update runs before the rest of the libraries are sourced.** It only
  fast-forwards a checkout with no staged/code changes (unstaged `config/*.conf`
  edits are preserved), validates all shell files with `bash -n`, reverts on
  validation failure, and re-executes `agent.sh` after a successful update.
  Update activity goes to `logs/auto_update.log`; it must never write into a
  tracked file, because that would dirty the tree and block future updates.
- **Collector discovery is dynamic and alphabetical by path.** Any `.sh` under
  `collectors/**` is sourced and run. Order matters: for example
  `collectors/icewarp/storage_paths.sh` runs before
  `collectors/storage/storage.sh`, which consumes the `icewarp.path.*` keys it
  sets.
- **All collected values live in `DATA`**, an associative array declared in
  `lib/common.sh`. Keys are flat, dotted, and namespaced by area
  (`os.cpu.load1`, `icewarp.backup.auto_enabled`, `disk.*`, `health.*`).
- **Collector failures are isolated.** `run_collector()` records `STATUS` and
  the last stderr line; one bad collector does not abort the run.
- **Health evaluation is independent of collection.** `lib/health.sh` reads
  `DATA` and writes `health.*` keys plus `HEALTH`. It does not call `tool.sh`.
- **PDFs are generated natively in Bash** (raw PDF objects, no wkhtmltopdf,
  pdflatex, or other binary). Layout is manual and page-overflow sensitive.

## Collector contract

Each file under `collectors/<category>/<name>.sh` must:

1. Define exactly one entry point: `collector_run() { ... }`.
2. Write values via `collector_set "<dotted.key>" "<value>"` (preferred) or
   directly into `DATA[...]`.
3. Use `iw_get`, `iw_get_domain`, `iw_tool_get`, or `iw_tool_get_multiline`
   from `lib/common.sh` for IceWarp values. `iw_get` tries, in order:
   `tool.sh` property → config-file regex → OS command fallback.
4. Wrap every external call in `timeout "$TOOL_TIMEOUT"` (default 5 s).
5. Return non-zero only for a real collector failure; empty/"not available"
   values should be set as empty or a sentinel and still return 0.
6. Avoid `exit`, global variable pollution, and defining helper functions with
   generic names. The collector is sourced into the agent's namespace and only
   `collector_run` is unset afterwards.

Dependency rules: standard Unix tools only (`curl`, `dig`, `openssl`, `awk`,
`date`, `find`, `grep`, `sed`, `df`, `firewall-cmd`). Do not add `jq`, `bc`,
Python, or a package dependency. Use `awk` for floating-point math and GNU
`grep -P`/`date -d` where already used.

### Windows collector contract

Each file under `windows/collectors/<Area>/<Name>.ps1` must:

1. Declare `param([Parameter(Mandatory = $true)][hashtable]$Context)`.
2. Return exactly one `IDictionary` (prefer `[ordered]@{}`) and write nothing
   else to the pipeline.
3. Use `Get-IceWarpSetting` or `Invoke-IceWarpTool` for `tool.exe` calls so the
   configured timeout applies.
4. Use namespaced dotted keys and keep names compatible with the Linux key
   contract when porting an existing collector.
5. Let failures throw; `Invoke-AgentCollector` isolates them, records `error`
   or `empty`, and continues.
6. Avoid `exit` and global state. Put reusable logic in `windows/lib/`.

Windows dependencies: Windows PowerShell 5.1, IceWarp `tool.exe`, and Pester
3.4+ for tests. Do not introduce a Bash dependency or call the Linux agent.

### Windows API reference

The authoritative Windows-side API reference is
`tool.v14.3.0.13.windows.help` (IceWarp 14.3.0.13 `APIConst.pas` from the
Windows server). It is **not** the same file as the Linux reference
`tool.v14.3.0.13.help`, and it must not be used as a substitute for it.

- Keep both files. Use the Windows reference when writing or reviewing
  Windows collectors.
- All Linux keys are present on Windows. Windows adds 4 keys:
  `C_API_DomainList_DefaultLimit`, `U_MailingLists`, `U_MailingListsList`,
  and `U_SlaveDomain`.
- `U_GROUPS` / `U_GROUPSLIST` are spelled `U_Groups` / `U_GroupsList` on
  Windows. The IDs and descriptions are the same.
- `U_MasterDomain` is `String [R]` on Windows and `String` on Linux. Read
  only on Windows.
- `C_OS` is `0` for Windows and `1` for Linux on both platforms.
- `C_Accounts_Policies_Auth_Schemes` is present; the incorrect
  `C_Mail_Security_AuthScheme` is absent.

The full comparison is in `docs/api-windows-vs-linux-v14.3.0.13.md`.

The API reference defines key names and IDs. It is not a substitute for
validating `tool.exe` output formatting, value semantics, service names, and
Windows-only behavior on the lab server. A Windows `tool.exe` search/list
export is still needed to confirm the property listing.

## Health rules (`lib/health.sh`)

`_health_set <name> <result> <message>` stores the result and exposes
`health.<name>.result` / `.message`. Result vocabulary in use:
`pass`, `warn`, `fail`, `critical`, `skip`, `info`.

Actual thresholds in code (the README is partially stale):

| Area | Rule |
|---|---|
| Memory | used > 90% critical, > 40% warn |
| Disk | free MB below `monitor.disk.alert_below_mb` fails; no fixed 80/95 split |
| CPU | 1-minute load vs `cores × monitor.cpu.threshold_percent / 100` (warn if above) |
| Password policy | inactive = fail; min length < 8 = warn |
| Login blocking | policy threshold > 10 = warn; must be active in policy or intrusion prevention |
| Backup | auto backup and Accounts/AntiSpam/GroupWare DB backups critical if disabled; last run < 2 d pass, 2–7 d warn, > 7 d critical |
| Watchdog | master + SMTP/POP3-IMAP/IM/VoIP/GroupWare critical if disabled |
| OS update | ≤ 7 d pass, 8–30 d warn, > 30 d critical |
| Summary | `SUMMARY_KEYS` is the nine-pillar list: backup, mail_flow, tls, access, threat, resources, os_update, monitoring, database |

`SUMMARY_KEYS` must match the keys passed to `_health_set`. This was previously
broken: the list referenced `backup.db.*.enabled` while the rules stored
`backup.db.*`, so database backups were silently skipped in the roll-up. It now
uses the real keys; keep both sides in sync when adding or renaming checks.

## Output contracts

`output/health.json` is a flat object of dotted keys, sorted, with:

- empty values → `null`
- numeric-looking values → unquoted numbers
- `true`/`false` → unquoted booleans
- everything else → escaped strings

Monitoring systems and the PDF renderers depend on key names. Treat key
renames/removals as breaking changes: update the collector, health rules,
`docs/checklist-map.md`, `docs/checklist-coverage.md`, and any report code that
reads the key.

`output/*` and `logs/*` are gitignored runtime artifacts.

## Configuration

- `config/agent.conf` — `AGENT_VERSION`, `CHECKLIST_VERSION`, `MONITOR_URL`,
  `SEND_DATA`, `OUTPUT_JSON`, `TOOL_TIMEOUT`, `COMPANY_NAME`, and the
  `AUTO_UPDATE_*` settings (`ENABLED`, `REMOTE`, `BRANCH`, `TIMEOUT`,
  `EXPECTED_ORIGIN`, `REEXEC`, `VALIDATE`, `LOG`, `LOG_MAX_BYTES`).
- `config/icewarp.conf` — install paths (`IW_*`), `IW_SSL_CERT`, DNS resolver,
  and `MAIL_HOSTNAME` / `MAIL_PUBLIC_IP` (required for PTR/SPF/DKIM/DMARC
  collectors).
- `config/recommended.conf` — desired `tool.sh` properties consumed only by the
  configurator (`--config`); it is **not** sourced by `agent.sh`. Keys must be
  the canonical names from `tool.help`; verify each new key with
  `grep -i '^<key> ' tool.help` before adding it. The configurator matches
  returned keys case-insensitively, but it cannot invent a property that does
  not exist in the installed IceWarp version.
- `config/checklist.conf.pdf` — checklist source of truth.
- `.env` — local Docker deployment values (gitignored). Copy `.env.example`
  and fill in real values; never commit `.env`.

`agent.sh` sources only `agent.conf` and `icewarp.conf` by basename; adding a
new `.conf` requires updating that loading loop.

## Automatic updates (v0.5.0)

`lib/auto_update.sh` runs before `agent.sh` sources the normal libraries:

1. Verify the checkout is a Git work tree, the checked-out branch matches
   `AUTO_UPDATE_BRANCH`, and `origin` matches `AUTO_UPDATE_EXPECTED_ORIGIN`.
2. Refuse staged changes or unstaged code changes. Unstaged `config/*.conf`
   edits are allowed and preserved; a same-file upstream change makes the
   fast-forward fail safely.
3. Fetch `AUTO_UPDATE_REMOTE` / `AUTO_UPDATE_BRANCH` with a timeout.
4. Fast-forward only when the local HEAD is an ancestor of the remote.
5. Run `bash -n` on `agent.sh` and every `*.sh`; revert to the old SHA if
   validation fails.
6. Log every attempt to `logs/auto_update.log` and re-exec `agent.sh` after a
   successful update.

It never merges, rebases, force-pulls, or overwrites local changes. Git/network
failures are non-fatal: the agent logs the reason and continues with the local
revision. Normal runs hold `.agent.lock` across the update and re-exec (the
same PID keeps the lock valid); `.agent.update.lock` serializes concurrent
checks, including `--check-update`.

Configuration is in `config/agent.conf`. The detailed operator guide, status
list, and recovery steps are in `docs/auto-update.md`. Every intentional
project change must also be recorded in `docs/update-log.md`.

## Reports

`lib/pdf.sh` (technical report) and `lib/management_report.sh` (executive
report) contain a small hand-written PDF writer:

- US Letter, 612×792 pt, margins/colors defined at the top of `pdf.sh`.
- Low-level helpers: `_pdf_rect`, `_pdf_text`, `_pdf_text_trunc`,
  `_layout_*` and `_mr_*`.
- Text escaping strips non-ASCII; reports are English-only.
- The technical cover and both report footers use `CHECKLIST_VERSION` (v1.14
  by default). The technical Health Summary uses the nine executive pillars:
  backup, mail_flow, tls, access, threat, resources, os_update, monitoring,
  database.
- The technical appendix groups raw keys by subsystem into key/value tables;
  table headers repeat when a group crosses a page boundary. Non-cover pages
  carry the report name and page number.
- The management report is a soft-cyberpunk executive summary: dark cover with
  score arc, executive overview, control-area scorecards with stacked status
  bars, and prioritized recommended actions. It evaluates the full checklist
  but prints only management-level findings.
- `--technician` defaults to `Parsavan`; `--company` falls back to the mail
  domain (`domain.primary.name`, `MAIL_DOMAIN`, first `tool.sh` domain,
  `MAIL_HOSTNAME`).

When editing reports, use the existing layout helpers and check page breaks,
long values, and empty strings. All PDF generation happens on every full run.

## Code style and conventions

- Bash, 4-space indentation, `local` variables, uppercase globals.
- Section banners and comments in English (project explicitly removed Persian
  comments).
- Use `[[ ... ]]`, arrays, and associative arrays; Bash 4+ is assumed.
- Preserve the no-dependency constraint and the timeout-on-every-call rule.
- Keep command-line flags backward compatible; `--only=` uses substring
  matching against the collector path.
- Configuration is authoritative for paths, but collectors should prefer live
  `DATA` values when an earlier collector resolved them (see `storage.sh`).
- Windows: PowerShell 5.1 syntax, 4-space indentation, approved verbs where
  practical, ASCII-only script files, and PSD1 configuration read through
  `Import-PowerShellDataFile`. Do not use PowerShell 7-only syntax.
- Windows and Linux are independent trees. Never make `windows/agent.ps1` call
  `agent.sh` or source `lib/*.sh`, and never make the Linux agent depend on
  Windows files.
- Windows runtime state belongs under `windows/output/` and `windows/logs/`;
  per-server config is `windows/config/agent.local.psd1` and is gitignored.

## Known issues / documentation drift

- `README.md` says "12 categories"; there are **14** collector directories and
  **80** collector scripts (**92** shell scripts in the repository overall).
- README threshold descriptions for disk (80/95) and CPU (15-min load, 50/95)
  do not match the current code.
- `docs/checklist-map.md` and `docs/checklist-coverage.md` reference files that
  no longer exist (e.g. `logging/auth_log.sh`, `logging/maintenance_log.sh`,
  `logging/sql_failed_log.sh`, `security/port_9001.sh`, `security/vrfy.sh`,
  `security/digest_md5.sh`, `security/cyren_folder.sh`, `os/os_update.sh`).
  Code is the source of truth; update docs when touching a collector.
- README references a `LICENSE` file that is not present in the repository.
- `maintenance/debug_agent.sh` hardcodes `PROJECT_ROOT=/root/iceauto`.
- `docker-compose.yml` now reads credentials and domains from `.env`
  (`.env.example` is the template). Plaintext credentials remain in the
  repository's git history from an earlier commit — treat them as compromised
  and rotate them. Never commit secrets.
- Automatic updates require a clean Git clone. A copied/ZIP install logs
  `not_git`; a dirty tree logs `dirty_tree` and keeps running the local code.
  The updater follows `origin/main` by default, so branch protection is the
  real security boundary: a push to that branch runs as the agent user.
- `logs/auto_update.log` is runtime data and gitignored. Do not add runtime
  update entries to `docs/update-log.md`; that file is the committed,
  human-readable change ledger.
- Windows 0.1.0 is a scaffold. It has one collector, no health evaluation, no
  PDFs, and no automatic update. Do not describe it as Linux feature parity or
  claim v1.14 item-level coverage on Windows.

## Knowledge graph (Graphify)

A code-only graph was generated with Graphify:

```bash
graphify query "how does health evaluation reach the PDF reports?"
graphify explain "evaluate_health()"
graphify path "evaluate_health()" "build_pdf()"
graphify god-nodes
```

Artifacts (local; `graphify-out/` is gitignored): `graphify-out/graph.json`
(313 nodes, 249 edges, 92 communities), `graphify-out/GRAPH_REPORT.md`,
`graphify-out/graph.html`. The graph is useful
for symbol inventory and intra-file relationships. Because collectors are
loaded dynamically with `source`, cross-file call edges are largely not
resolved — do not treat it as a complete call graph. Rebuild with:

```bash
graphify extract . --code-only
graphify cluster-only . --no-label
```

## Change checklist

For a configurator key:

1. Confirm the key exists in `tool.help` and is writable (not `r/o`).
2. Add it to `config/recommended.conf` as `key|value|description`.
3. Run `./agent.sh --config` on the lab server and expect no
   `key not found` lines for it before using `--apply`.

For a collector change:

1. Add/modify `collectors/<area>/<name>.sh` with `collector_run()`.
2. Use `collector_set` and namespaced keys; timeout external calls.
3. Run `maintenance/collector_tester.sh <name>` on a lab server.
4. If the item is evaluated, update `lib/health.sh` and the summary keys.
5. Update `docs/checklist-map.md` / `docs/checklist-coverage.md`.
6. Run the full agent and inspect `output/health.json` plus both PDFs.
7. Verify the JSON remains valid and existing key names are unchanged unless
   intentionally breaking.
8. Record the change in `docs/update-log.md` and `CHANGELOG.md`, and update
   every affected guide (`README.md`, `CLAUDE.md`, `docs/auto-update.md`, or
   the checklist docs). Replace the `pending` commit hash in the activity log
   after committing.

For a Windows change:

1. Edit only the `windows/` tree unless a repository-wide document or ignore
   rule must change.
2. Keep Windows PowerShell 5.1 compatibility and ASCII-only script files.
3. Run `windows\tests\Run-Tests.ps1` and a manual `windows\agent.ps1` smoke
   run. A live `tool.exe` check is still required for real values.
4. Do not invoke `agent.sh` or source Linux libraries from Windows code.
5. Keep `windows/VERSION`, `windows/CHANGELOG.md`, and Windows tags
   independent of Linux.
6. Update `windows/README.md`, `windows/docs/deployment.md`, and the root
   platform notes when behavior changes.
