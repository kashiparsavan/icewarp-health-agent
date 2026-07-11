# IceWarp Health Agent

Curled and run on an IceWarp production server from a monitoring server.
Runs all collectors, evaluates the results against health rules, writes a
JSON file and a PDF report, and (when enabled) sends the JSON to the
monitoring server.

```
./agent.sh            # full run: collect -> evaluate -> JSON -> PDF -> send
./agent.sh --report    # same, but prints the report to stdout instead of sending
./agent.sh --list      # list all available collectors
```

Current Version : 0.3.0

## Status (as of 2026-07-11, audited against actual code + a live run)

- 60 collectors implemented across 12 categories (general, icewarp, os,
  storage, dns, smtp, mailserver, security, queue, logging, http, fulltext).
- Of the 63 checklist rows tracked in `docs/checklist-map.md`: 31 fully
  verified against `tool.help`, 16 collected via a config/OS fallback, 3
  implemented but with unverified syntax, 13 not yet located. See that file's
  appendix for ~26 additional working collectors not yet cross-referenced to
  checklist item names.
- Health Rules (`lib/health.sh`) and PDF report generation (`lib/pdf.sh`) are
  implemented as of this version - see `docs/roadmap.md` for what's still open.
- The monitoring-server sender (`lib/transport.sh`) is implemented but not
  yet validated against a real endpoint - `SEND_DATA` defaults to `0`.

See `docs/roadmap.md` for the full milestone breakdown and `docs/checklist-map.md`
for the item-by-item checklist mapping.
