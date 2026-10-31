# Change and Activity Log

This file is the human-readable, version-controlled activity ledger for the
project. It records every intentional change so operators and future
maintainers can see what changed, when, and why.

There are two complementary logs:

| Log | Scope | Location |
|---|---|---|
| This file plus `CHANGELOG.md` | Source, configuration, and documentation changes | Committed to Git |
| Automatic update log | Runtime fetch/update attempts on each server | `logs/auto_update.log` (gitignored) |

Do **not** append runtime events to this file. Runtime logging must stay out of
the working tree, otherwise the next automatic fast-forward would be blocked
by a dirty checkout.

## Maintenance rule

For every change:

1. Add a row to the table below.
2. Add or update the matching `CHANGELOG.md` entry.
3. Update the relevant guide (`README.md`, `CLAUDE.md`, `docs/auto-update.md`,
   or the checklist docs).
4. Record the commit hash after committing. If the hash is not yet known, use
   `pending` and replace it in the follow-up documentation commit.

## Activity log

| Date (UTC) | Commit | Type | Summary | Documentation updated |
|---|---|---|---|---|
| 2026-10-31 | `pending` | Fix / security | Phase 0 step 1: shared `norm_date`/`_days_ago`/`redact_dsn` in `lib/common.sh`; removed 3 duplicate `_days_ago`; ISO antispam/antivirus dates (+`*_raw`); DSN password redaction in 4 collectors plus a `json.sh` safety net; fixed `database.type` for `host:port` DSNs. | `lib/common.sh`, `lib/health.sh`, `lib/pdf.sh`, `lib/management_report.sh`, `lib/json.sh`, `collectors/icewarp/{antispam,antivirus,database_type,directory_cache,database_backup}.sh`, `collectors/watchdog/watchdog_percentage.sh`, `CHANGELOG.md`, `CLAUDE.md` |
| 2026-10-26 | `53a4099` | Docs / API | Added the Windows 14.3.0.13 `APIConst.pas` as `tool.v14.3.0.13.windows.help` and compared it with the Linux reference. All Linux keys are present on Windows; Windows adds 4 keys, changes the capitalization of 2 keys, and marks `U_MasterDomain` read-only. No collector or checklist changes required. | `tool.v14.3.0.13.windows.help`, `docs/api-windows-vs-linux-v14.3.0.13.md`, `docs/api-update-v14.3.0.12-to-14.3.0.13.md`, `docs/checklist-coverage.md`, `windows/README.md`, `CHANGELOG.md` |
| 2026-10-26 | `f666dd4` | Docs | Added the Windows API reference section to `CLAUDE.md` and recorded the Windows-vs-Linux differences in the changelog and activity log. | `CLAUDE.md`, `CHANGELOG.md`, `docs/update-log.md` |
| 2026-10-26 | `633e31b` | Fix / docs | Corrected the 14.3.0.13 API note: the supplied reference is Linux, not Windows. The Linux v12-to-v13 comparison is unchanged and valid; the Windows file hash differs, but no key-level Windows comparison was performed. | `docs/api-update-v14.3.0.12-to-14.3.0.13.md`, `docs/checklist-coverage.md`, `docs/update-log.md`, `CHANGELOG.md` |
| 2026-10-26 | `fbca3f3` | Docs / API | Added `tool.v14.3.0.13.help` from the supplied Linux `APIConst.pas`; verified it is byte-identical to the Linux 14.3.0.12 reference (1,914 assignment lines; 0 added, removed, or changed), so no Linux collector, health-rule, checklist, or report changes are required. The Windows 14.3.0.13 file has a different SHA-256; no key-level Windows comparison was performed. | `tool.v14.3.0.13.help`, `docs/api-update-v14.3.0.12-to-14.3.0.13.md`, `docs/checklist-coverage.md`, `CHANGELOG.md` |
| 2026-10-26 | `9f30bdd` | Feature / Windows | Added an independent Windows PowerShell 5.1 scaffold under `windows/`: entry point, PSD1 config, logging, timeout-bounded `tool.exe` wrapper, flat JSON, `General/Version` collector, and Pester smoke tests. Linux runtime and auto-update untouched. | `windows/README.md`, `windows/CHANGELOG.md`, `windows/docs/deployment.md`, `README.md`, `CLAUDE.md`, `CHANGELOG.md`, `docs/roadmap.md`, `docs/auto-update.md`, `docs/checklist-coverage.md`, `.gitattributes`, `.gitignore` |
| 2026-10-26 | `342a469` | Fix / Windows | Normalized empty Windows JSON values to `null` to match the Linux JSON contract; added a smoke-test assertion and documented the behavior. | `windows/lib/Json.ps1`, `windows/tests/Agent.Smoke.Tests.ps1`, `windows/README.md`, `windows/CHANGELOG.md`, `CLAUDE.md`, `CHANGELOG.md` |
| 2026-10-19 | `dd82f5d` | Docs / security | Added `CLAUDE.md`; moved Compose credentials to required `.env` variables; added `.env.example`; fixed backup DB summary keys in `lib/health.sh`. | `CLAUDE.md`, `README.md`, `.env.example`, `.gitignore`, `.gitattributes` |
| 2026-10-19 | `92f711f` | Fix | Replaced guessed/legacy configurator properties with 78 canonical IceWarp v14.3 `tool.help` keys; added missing SMTP, security, login, watchdog, and monitor settings; made key matching case-insensitive. | `config/recommended.conf`, `lib/configurator.sh`, `CLAUDE.md` |
| 2026-10-19 | `e15499d` | Feature | Added automatic fast-forward Git updates before every agent run, re-exec after update, shell syntax validation with rollback and config preservation, branch/origin/clean-tree guards, run/update locking, and append-only audit logging. | `agent.sh`, `lib/auto_update.sh`, `lib/common.sh`, `config/agent.conf`, `VERSION`, `README.md`, `CHANGELOG.md`, `CLAUDE.md`, `docs/auto-update.md`, `docs/update-log.md`, `docs/roadmap.md` |
| 2026-10-19 | `b266ab7` | Fix | Required the checked-out branch to match `AUTO_UPDATE_BRANCH`; documented the branch guard and clarified clean-tree/config-edit behavior. | `lib/auto_update.sh`, `config/agent.conf`, `README.md`, `CHANGELOG.md`, `CLAUDE.md`, `docs/auto-update.md` |
| 2026-10-19 | `b91d3ed` | Docs | Added first-time activation and customized-checkout upgrade instructions, including config backup/stash/pull/reapply steps. | `docs/auto-update.md` |
| 2026-10-20 | `6f84ea6` | Feature / reports | Redesigned the management report; added nine-pillar Health Summary, grouped technical appendix tables, page footer/page numbers, company domain fallback, Parsavan technician default, and v1.14 checklist label. Bumped release to 0.6.0. | `README.md`, `CLAUDE.md`, `CHANGELOG.md`, `VERSION`, `config/agent.conf`, `lib/health.sh`, `lib/pdf.sh`, `lib/management_report.sh`, `lib/common.sh`, `agent.sh`, `docs/checklist-coverage.md`, `docs/checklist-map.md`, `docs/roadmap.md`, `docs/update-log.md` |

## Runtime update log format

`logs/auto_update.log` is pipe-delimited:

```text
timestamp|status|old=<sha>|new=<sha>|branch=<branch>|detail
```

See `docs/auto-update.md` for the full status list, recovery steps, and
security notes.
