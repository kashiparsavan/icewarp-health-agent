# IceWarp Health Agent

The Linux agent is a dependency-free, Bash-based health checking and reporting
tool for IceWarp mail servers. It runs locally on the mail server, collects data
via `tool.sh`, OS commands, and DNS lookups, evaluates the results against a
defined checklist, and generates three output files.

A separate Windows implementation lives under `windows/` and uses Windows
PowerShell. It is independent: it does not call `agent.sh` and does not source
anything from the Linux `lib/` directory.

| Platform | Entry point | Version | Status |
|---|---|---|---|
| Linux | `./agent.sh` | 0.6.0 | Production |
| Windows | `windows/agent.ps1` | 0.1.0 | Scaffold |

## Output Files

The Linux agent generates these files:

| File | Purpose |
|------|---------|
| `output/health.json` | Raw structured data (type-aware JSON) for monitoring systems |
| `output/report.pdf` | Full technical report with all checklist items, values, and notes |
| `output/management_report.pdf` | Non-technical executive summary with scorecards and prioritized actions |

The Windows 0.1.0 scaffold currently writes flat JSON only. PDF and management
report output are not ported yet.

## Quick Start (Linux)

```bash
git clone https://github.com/kashiparsavan/icewarp-health-agent.git
cd icewarp-health-agent
./agent.sh --report --technician="Your Name" --company="Your Company"
```

### Command-Line Options

| Option | Description |
|--------|-------------|
| `./agent.sh` | Full run: collect, evaluate, JSON, PDF |
| `./agent.sh --report` | Same, and print summary to stdout |
| `./agent.sh --list` | List all available collectors |
| `--only=<filter>` | Run only collectors containing `<filter>` (comma-separated) |
| `--technician="Name"` | Override technician name in reports (default: `Parsavan`) |
| `--company="Name"` | Override company name in reports (default: the domain that carries mail) |
| `--config` / `--config --apply` | Preview or apply recommended IceWarp settings |
| `--check-update` | Check for a newer Git revision, then exit |
| `--no-auto-update` | Skip the automatic Git update for this run |
| `--auto-update` | Force an update check even if disabled in config |
| `--no-update` | Deprecated no-op; use `--no-auto-update` |

Current Linux version: **0.6.0**. Current Windows scaffold version: **0.1.0**
(`windows/VERSION`).

When `--company` is omitted, the agent uses `domain.primary.name`, then
`MAIL_DOMAIN`, then the first domain returned by `tool.sh`, then the configured
mail hostname. When `--technician` is omitted, it uses `Parsavan`. Both defaults
are overridden by the command-line flags.

### Automatic updates

The agent updates itself before every execution. It checks the configured Git
branch (`origin/main` by default), fast-forwards only when there are no staged
or code changes (unstaged `config/*.conf` edits are preserved), validates the
new shell files, and re-executes itself. Every attempt is written to
`logs/auto_update.log`.

The updater never merges, rebases, force-pulls, or overwrites local changes.
Network and Git failures are logged and the current revision continues to run.
See [`docs/auto-update.md`](docs/auto-update.md) for the full behavior,
configuration, log statuses, and recovery steps.

This only works from a Git clone. A ZIP/copied install runs the local files and
skips the update check. An existing clone must pull this release once manually
(`git pull --ff-only origin main`); after that, every run checks automatically.

## Windows Agent (scaffold)

The Windows implementation is additive and independent. It targets Windows
PowerShell 5.1 and does not use Bash, `agent.sh`, or the Linux libraries.

```powershell
cd windows
Copy-Item .\config\agent.example.psd1 .\config\agent.local.psd1
notepad .\config\agent.local.psd1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\agent.ps1 -Report
```

What works in 0.1.0:

- CLI entry point with `-Report`, `-List`, `-Only`, `-Company`, `-Technician`,
  `-ConfigPath`, and `-Help`.
- PSD1 configuration with a tracked example and ignored per-server file.
- Timeout-bounded `tool.exe` wrapper and isolated collector execution.
- Flat, type-aware `windows/output/health.json`.
- One sample collector: `windows/collectors/General/Version.ps1`.
- Pester smoke tests.

What is not ported yet: the full 113-item checklist, health rules, PDF and
management reports, DNS collectors, and automatic updates. See
[`windows/README.md`](windows/README.md) and
[`windows/docs/deployment.md`](windows/docs/deployment.md) for setup and
scheduling. The Linux updater remains Linux-only and follows `origin/main`.

## Docker deployment (Linux / IceWarp server container)

`docker-compose.yml` starts the IceWarp server container, not the health agent.
Copy the example environment file, fill in real values, and start it:

```bash
cp .env.example .env
# edit .env with your domain, hostname, and credentials
docker compose up -d
```

`.env` is gitignored. Never commit credentials. If credentials were ever
committed to this repository, rotate them immediately.

Architecture
icewarp-health-agent/
├── agent.sh                      # Entry point and self-update dispatch
├── lib/
│   ├── auto_update.sh            # Git fetch / fast-forward / audit logging
│   ├── common.sh                 # Shared utilities (collector_set, iw_get, etc.)
│   ├── health.sh                 # Health evaluation rules
│   ├── pdf.sh                    # Full technical PDF generator
│   ├── management_report.sh      # Executive summary PDF generator
│   ├── json.sh                   # JSON exporter
│   └── transport.sh              # HTTP transport (disabled by default)
├── collectors/                   # Data collectors organized by category
├── config/
│   ├── agent.conf                # General agent and auto-update settings
│   ├── icewarp.conf              # IceWarp-specific paths
│   └── checklist.conf.pdf        # Checklist definition (source of truth)
├── docs/
│   ├── auto-update.md            # Auto-update behavior and recovery
│   ├── checklist-map.md          # Mapping of checklist items to collectors
│   ├── roadmap.md                # Project milestones and future plans
│   ├── tool-index.md             # IceWarp tool.sh API reference
│   └── update-log.md             # Human-readable change/activity ledger
├── logs/                         # Runtime logs (gitignored)
└── output/                       # Generated reports (gitignored)

The independent Windows tree is under `windows/`; see `windows/README.md`.

Features
Health Evaluation
Percentage-based thresholds:

Memory: WARN above 40%, CRITICAL above 90%

Disk: WARN at 80% or above, CRITICAL at 95% or above

CPU: 15-minute load, WARN above 50%, CRITICAL above 95%

Backup: Main auto backup and 4 database backups (Accounts, AntiSpam,
GroupWare, Directory Cache) evaluated separately.

Watchdog: Main control and 4 services (SMTP, POP3/IMAP, IM/VoIP,
GroupWare) plus interval check.

Intrusion Prevention: All numeric values validated against expected
defaults (10, 5, 5, 5, 9.00, 5, 30).

License: Uses c_evalexpirationtime for Trial/Evaluation licenses.
Handles SaaS and Cloud correctly.

Archive: Separate checks for Active, Directory, IMAP integration,
Do Not Archive Spam, and Backup Deleted Messages.

Logging: Non-zero log level means PASS, zero means CRITICAL.

Cloud Features and DIGEST-MD5: Inverted polarity (disabled means PASS).

OS Update: Time-based (under 7 days PASS, 7 to 30 days WARN, over 30
days CRITICAL).

Swap Monitoring: Checks swap usage in the last 7 days.

Health Summary (Cover Page)
The cover rolls detailed checks into nine executive control areas: Backup &
Recovery, Mail Flow & DNS, Transport Security, Access & Authentication, Threat
Protection, Server Resources, OS & Patching, Monitoring & Watchdog, and
Database Platform. The overall Health Summary status is based on these
pillars; the full checklist remains available in the technical report.

Reports
Technical PDF (report.pdf): All checklist items with values and notes. The
cover carries the v1.14 checklist label and the nine-pillar Health Summary;
the appendix groups raw keys by subsystem into readable tables. Pages carry
report name and page numbers.

Management PDF (management_report.pdf): Modern management summary with a
score arc, executive overview, control-area scorecards, stacked status bars,
and prioritized recommended actions. It evaluates the full checklist but does
not print every item.

Both PDFs are generated natively in Bash. No wkhtmltopdf, no
pdflatex, no additional dependencies.

Remote Execution
# From a monitoring server:
ssh root@icewarp-server "/opt/icewarp-health-agent/agent.sh --report"
scp root@icewarp-server:/opt/icewarp-health-agent/output/*.pdf .

Dependencies
The Linux agent has no runtime, package manager, database, or web server. It is
pure Bash plus standard Unix tools:

curl, dig, openssl, awk, date, find, grep, sed, firewall-cmd.

`git` is additionally required for automatic updates. Without it, the agent
logs `git_missing` and continues with the local code.

The Windows agent requires Windows PowerShell 5.1 and IceWarp `tool.exe`. Pester
3.4+ is needed only to run its tests.

Checklist
Reports reference IceWarp CheckList **v1.14** (the internal edition label
configured by `CHECKLIST_VERSION`). The item set is still the v1.12-mapped
113-item checklist; the v1.14 label changes the report metadata, not the
collector coverage. See docs/checklist-map.md for item-by-item mapping between
checklist entries and collectors.

Configuration
Default settings work out of the box. Optional customization:

config/agent.conf: General settings (timeouts, monitor URL), the report
`CHECKLIST_VERSION` label, and automatic update controls
(`AUTO_UPDATE_ENABLED`, branch, origin, log path, and validation).

config/icewarp.conf: IceWarp-specific paths.

MAIL_HOSTNAME and MAIL_PUBLIC_IP are required for DNS collectors
(PTR, SPF, DKIM, DMARC).

IW_SSL_CERT is the path to the SSL certificate.

Known Limitations
Server version headers (Server: IceWarp/14.3.0.11 and X-Version)
cannot be removed or replaced by IceWarp native configuration. The
c_webservice_customhttpincludetext parameter only appends text to
the Server header.

License seat count is not available via tool.sh. It requires the
Admin API or a database query.

Remote DB (MySQL) checks are not implemented yet. They need a separate
remote-execution strategy.

Transport (SEND_DATA=1) is implemented but not yet validated against
a real monitoring endpoint.

The Windows 0.1.0 scaffold does not yet implement the full checklist, health
rules, PDF reports, DNS collectors, or automatic updates. It writes JSON and
one sample collector only.

Automatic updates require a Git clone with the expected `origin` and no
staged or unstaged code changes. Unstaged edits to `config/*.conf` are
allowed and preserved; if an upstream commit touches the same config file,
the fast-forward fails safely and is logged. A copied/ZIP install, a different
checked-out branch, a diverged branch, or a missing `git` binary causes the
updater to skip with a logged reason. Because the
updater follows a branch and runs as the agent user, protect that branch;
anyone who can push to it can execute code on the mail server.

Documentation
docs/auto-update.md: Automatic update behavior, configuration, log statuses,
and recovery.

docs/update-log.md: Human-readable activity ledger; update it with every
intentional change.

docs/checklist-map.md: Mapping between checklist items and collectors.

docs/roadmap.md: Project milestones and future work.

docs/tool-index.md: Reference of tool.sh properties.

windows/README.md: Windows scaffold, configuration, collector contract, and
tests.

windows/docs/deployment.md: Windows Task Scheduler, permissions,
troubleshooting, and update guidance.

CHANGELOG.md: Linux version history.

windows/CHANGELOG.md: Windows version history.

CLAUDE.md: Guidance for AI agents and maintainers working in the repository.

License
See the LICENSE file.


