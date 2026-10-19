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
| 2026-10-19 | `dd82f5d` | Docs / security | Added `CLAUDE.md`; moved Compose credentials to required `.env` variables; added `.env.example`; fixed backup DB summary keys in `lib/health.sh`. | `CLAUDE.md`, `README.md`, `.env.example`, `.gitignore`, `.gitattributes` |
| 2026-10-19 | `92f711f` | Fix | Replaced guessed/legacy configurator properties with 78 canonical IceWarp v14.3 `tool.help` keys; added missing SMTP, security, login, watchdog, and monitor settings; made key matching case-insensitive. | `config/recommended.conf`, `lib/configurator.sh`, `CLAUDE.md` |
| 2026-10-19 | `e15499d` | Feature | Added automatic fast-forward Git updates before every agent run, re-exec after update, shell syntax validation with rollback and config preservation, origin/clean-tree guards, run/update locking, and append-only audit logging. | `agent.sh`, `lib/auto_update.sh`, `lib/common.sh`, `config/agent.conf`, `VERSION`, `README.md`, `CHANGELOG.md`, `CLAUDE.md`, `docs/auto-update.md`, `docs/update-log.md`, `docs/roadmap.md` |

## Runtime update log format

`logs/auto_update.log` is pipe-delimited:

```text
timestamp|status|old=<sha>|new=<sha>|branch=<branch>|detail
```

See `docs/auto-update.md` for the full status list, recovery steps, and
security notes.
