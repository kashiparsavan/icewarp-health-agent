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

Command-Line Options
Option	Description
./agent.sh	Full run: collect, evaluate, JSON, PDF
./agent.sh --report	Same, and print summary to stdout
./agent.sh --list	List all available collectors
--only=<filter>	Run only collectors containing <filter> (comma-separated)
--technician="Name"	Override technician name in reports
--company="Name"	Override company name in reports
--no-update	Skip OS update check
Current Version
0.4.0

Architecture
icewarp-health-agent/
├── agent.sh                      # Entry point
├── lib/
│   ├── common.sh                 # Shared utilities (collector_set, iw_get, etc.)
│   ├── health.sh                 # Health evaluation rules
│   ├── pdf.sh                    # Full technical PDF generator
│   ├── management_report.sh      # Executive summary PDF generator
│   ├── json.sh                   # JSON exporter
│   └── transport.sh              # HTTP transport (disabled by default)
├── collectors/                   # Data collectors organized in 12 categories
├── config/
│   ├── agent.conf                # General agent settings
│   ├── icewarp.conf              # IceWarp-specific paths
│   └── checklist.conf.pdf        # Checklist definition (source of truth)
├── docs/
│   ├── checklist-map.md          # Mapping of checklist items to collectors
│   ├── roadmap.md                # Project milestones and future plans
│   └── tool-index.md             # IceWarp tool.sh API reference
└── output/                       # Generated reports

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
Zero. Pure Bash plus standard Unix tools:
curl, dig, openssl, awk, date, find, grep, sed,
firewall-cmd.

Checklist
Based on IceWarp CheckList v1.12.
See docs/checklist-map.md for item-by-item mapping between checklist
entries and collectors.

Configuration
Default settings work out of the box. Optional customization:

config/agent.conf: General settings (timeouts, monitor URL).

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

Documentation
docs/checklist-map.md: Mapping between checklist items and collectors.

docs/roadmap.md: Project milestones and future work.

docs/tool-index.md: Reference of tool.sh properties.

CHANGELOG.md: Version history.

License
See the LICENSE file.


