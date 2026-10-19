# CLAUDE.md

Guidance for Claude Code (and other AI agents) working in this repository.

## What this project is

**IceWarp Health Agent** is a dependency-free, Bash-based health-check and
reporting tool for IceWarp mail servers. It runs on the mail server, collects
data from `tool.sh`, OS commands, and DNS, evaluates the results against the
IceWarp Checklist (v1.12), and produces:

- `output/health.json` — flat, type-aware JSON for monitoring systems
- `output/report.pdf` — full technical report
- `output/management_report.pdf` — non-technical executive summary

Current version: **0.4.0** (`VERSION`, `config/agent.conf`). Target platform:
Linux (RHEL/Rocky/AlmaLinux and Debian/Ubuntu families) with Bash 4+ and GNU
coreutils. There is no runtime, package manager, database, or web server.

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
./agent.sh --no-update                      # parsed but currently has no effect
```

Development / diagnostics (still Linux + IceWarp):

```bash
bash -n agent.sh lib/*.sh collectors/**/*.sh    # syntax check
./maintenance/collector_tester.sh <collector>   # run one collector, print DATA keys
./maintenance/collectors_validity_checker.sh    # run all collectors + validate health.json
./maintenance/collectors_validity_checker.sh --list
```

There is no unit-test framework and no CI. A meaningful test requires
`/opt/icewarp/tool.sh` and a live IceWarp installation; on a plain dev machine
collectors will mostly return empty/skip values. Do not claim a runtime fix was
verified without exercising it on a lab server.

## Architecture and data flow

```
agent.sh
  ├─ sources lib/common.sh, health.sh, pdf.sh, json.sh,
  │  management_report.sh, transport.sh, configurator.sh
  ├─ sources config/agent.conf and config/icewarp.conf
  ├─ find collectors -name '*.sh' | sort → source + collector_run() for each
  │    └─ collectors write flat dotted keys into DATA[]
  ├─ evaluate_health()  → HEALTH[] + health.<item>.result/.message in DATA[]
  ├─ build_json()       → output/health.json
  ├─ send_json()        → optional POST to $MONITOR_URL when SEND_DATA=1
  ├─ build_pdf()        → output/report.pdf
  └─ build_management_pdf() → output/management_report.pdf
```

Key implementation details:

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
| Summary | only a fixed `SUMMARY_KEYS` list feeds `health.summary.*` |

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

- `config/agent.conf` — `AGENT_VERSION`, `MONITOR_URL`, `SEND_DATA`,
  `OUTPUT_JSON`, `TOOL_TIMEOUT`, `COMPANY_NAME`.
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

## Reports

`lib/pdf.sh` (technical report) and `lib/management_report.sh` (executive
report) contain a small hand-written PDF writer:

- US Letter, 612×792 pt, margins/colors defined at the top of `pdf.sh`.
- Low-level helpers: `_pdf_rect`, `_pdf_text`, `_pdf_text_trunc`,
  `_layout_*` and `_mr_*`.
- Text escaping strips non-ASCII; reports are English-only.
- The management report shows only the 8 headline categories: backup,
  RAM, CPU, HDD, login blocking, SSL, OS update, password policy.

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
