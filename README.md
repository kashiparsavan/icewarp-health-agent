# IceWarp Health Agent

A dependency-free, Bash-based health checking and reporting tool for IceWarp
mail servers. It runs locally on the mail server, collects data via
`tool.sh`, OS commands, and DNS lookups, evaluates the results against a
defined checklist, and generates three output files.

## Output Files

| File | Purpose |
|------|---------|
| `output/health.json` | Raw structured data (type-aware JSON) for monitoring systems |
| `output/report.pdf` | Full technical report with all checklist items, values, and notes |
| `output/management_report.pdf` | Non-technical executive summary with visual status grid |

## Quick Start

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
| `--technician="Name"` | Override technician name in reports |
| `--company="Name"` | Override company name in reports |
| `--config` / `--config --apply` | Preview or apply recommended IceWarp settings |
| `--check-update` | Check for a newer Git revision, then exit |
| `--no-auto-update` | Skip the automatic Git update for this run |
| `--auto-update` | Force an update check even if disabled in config |
| `--no-update` | Deprecated no-op; use `--no-auto-update` |

Current version: **0.5.0**.

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

### Docker deployment (IceWarp server container)

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
Only 8 key categories are shown for quick overview:
Backup, Resource - RAM, Resource - CPU, Resource - HDD, Login Blocking,
SSL, OS Update, Password Policy.

Reports
Technical PDF (report.pdf): All checklist items with values and notes.

Management PDF (management_report.pdf): Visual status grid only,
non-technical.

Both PDFs are generated natively in Bash. No wkhtmltopdf, no
pdflatex, no additional dependencies.

Remote Execution
# From a monitoring server:
ssh root@icewarp-server "/opt/icewarp-health-agent/agent.sh --report"
scp root@icewarp-server:/opt/icewarp-health-agent/output/*.pdf .

Dependencies
No runtime, package manager, database, or web server. Pure Bash plus standard
Unix tools:

curl, dig, openssl, awk, date, find, grep, sed, firewall-cmd.

`git` is additionally required for automatic updates. Without it, the agent
logs `git_missing` and continues with the local code.

Checklist
Based on IceWarp CheckList v1.12.
See docs/checklist-map.md for item-by-item mapping between checklist
entries and collectors.

Configuration
Default settings work out of the box. Optional customization:

config/agent.conf: General settings (timeouts, monitor URL) and automatic
update controls (`AUTO_UPDATE_ENABLED`, branch, origin, log path, and
validation).

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

CHANGELOG.md: Version history.

CLAUDE.md: Guidance for AI agents and maintainers working in the repository.

License
See the LICENSE file.


