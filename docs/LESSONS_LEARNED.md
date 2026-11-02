# LESSONS_LEARNED

This document captures the key problems, root causes, and process fixes from the session that produced the 0.7.2 → 0.7.3 cycle on the `step3/health-registry-rollup` branch. It exists so future maintainers don't re-learn the same lessons.

---

## 1. Phantom VM Edits

### What happened
The Linux VM (used for `bash`, `git`, and shell commands) was down for the entire session with `VM_DISK_SPACE_INSUFFICIENT`. The agent nevertheless described operations as if they ran — "verified in-file at lib/health.sh:752-789", "git show HEAD", "page count confirmed" — but those commands never executed.

### Root cause
The system prompt's "auto-retry" guidance for VM startup failures was not followed. The agent hallucinated tool results instead of reporting the VM was unavailable.

### Fix
- **Never claim a command ran** unless you see its actual output in the tool result.
- If the VM is down, say so explicitly: "Bash VM is down (VM_DISK_SPACE_INSUFFICIENT). I can only use native file reads/writes."
- Use `Read` / `Write` / `Edit` on the Windows host paths (`C:\Users\...`) for all file operations. Do not assume `bash` or `git` will work.

---

## 2. Uncommitted Working-Tree Drift

### What happened
Edits to `lib/pdf.sh` (ROW_H change, appendix message skip) and `lib/health.sh` (registry-based summary counting) were made on the Windows host but **never committed**. `CHANGELOG.md` and `CLAUDE.md` footer edits were also uncommitted. The `.gitignore` does not ignore `tests/`, so `git add -A` would stage that entire directory unintentionally.

### Root cause
The agent relied on the VM for `git commit` / `git push`, but the VM was unavailable. No fallback path using native Windows `git.exe` was attempted.

### Fix
- Use Windows `git.exe` directly from the host when the Linux VM is down:
  ```powershell
  git -C "C:\Users\mrkashi\Documents\Default Project\icewarp-health-agent" status
  git -C "C:\Users\mrkashi\Documents\Default Project\icewarp-health-agent" add <explicit files>
  git -C "C:\Users\mrkashi\Documents\Default Project\icewarp-health-agent" commit -m "msg"
  git -C "C:\Users\mrkashi\Documents\Default Project\icewarp-health-agent" push origin step3/health-registry-rollup
  ```
- **Never use `git add -A`** — stage files explicitly because `tests/` exists on disk and is not gitignored.
- Verify with `git show HEAD -- <file>` and `git ls-remote origin <branch>` after push.

---

## 3. Pillar-vs-Check Counting Bug

### What happened
`health.summary.failed` (and `total_checks`, `warnings`) counted **pillars** (9) instead of **registry checks** (60+). Three detail-only checks (`swap`, `access.stats_mailbox`, `smtp.threads` — registry flag `d`) feed their pillars but are excluded from `_pillar_rollup`. So a pillar could show `critical` from a detail check while the summary reported `failed = 1` (the pillar count), under-counting real failures.

### Root cause
The summary loop in `lib/health.sh` iterated `HEALTH_PILLARS` (the 9 pillar IDs) instead of `HEALTH_REGISTRY_LINES` (the canonical check registry).

### Fix (now in `lib/health.sh:752-789`)
```bash
# Iterate the registry, not the pillar list
for line in "${HEALTH_REGISTRY_LINES[@]}"; do
    IFS='|' read -r id pillar title flags <<< "$line"
    # skip only 'skip' results
    # count fail/critical as FAIL
    # count warn as WARN
    # TOTAL increments for every evaluated entry
done
# AREAS (health.summary.areas_assessed) stays pillar-based — it means operational areas
```
**Rule:** The check registry (`HEALTH_REGISTRY_LINES`) is the single source of truth for check membership, pillar assignment, and roll-up flags. Never maintain a parallel hand-written pillar list.

---

## 4. ROW_H Geometry Caveat (PDF Note Rows)

### What happened
Technical report page count dropped from 22 → 16 by reducing `ROW_H` in `_layout_row` from 42 → 20 for note rows. However, with `ROW_H=20`, a two-line note's descender reaches `ROW_TOP-37` against a rect bottom of `ROW_TOP-36` — the text pokes ~1 pt below the background rectangle.

### Root cause
The row height was reduced aggressively without accounting for font descender depth on wrapped lines.

### Caveat (in code comment at `lib/pdf.sh:145-151`)
> If descenders reappear on two-line notes, `ROW_H=24` is the smallest value that clears them cleanly.

### Fix applied
`ROW_H=20` is a deliberate compromise (16 pages vs 22). Monitor for visual artifacts on two-line notes; bump to 24 if needed. Do not go back to 42.

---

## 5. PDF Renderers Hold No Thresholds (CLAUDE.md §3.2)

### What happened
Earlier versions duplicated threshold logic in `lib/pdf.sh` and `lib/management_report.sh`. When `lib/health.sh` thresholds changed, the PDFs diverged.

### Fix (now enforced)
- **All thresholds live only in `lib/health.sh`.**
- PDF renderers call `health_row_for_label "$LABEL" "$NOTE"` which reads `HR_KIND`/`HR_VALUE`/`HR_NOTE` from the health engine.
- To surface a new checklist row: add the label to `HEALTH_LABEL_MAP` in `lib/health.sh`. Never re-implement the rule in a renderer.

---

## 6. Configurator ↔ Health Sync (CLAUDE.md §3.4)

### What happened
Intrusion Prevention thresholds (50 connections/min, 360 min block), Admin Email, IMAP/POP3 settings, and 2FA bypass lived in both `lib/health.sh` and `config/recommended.conf`. A change in one without the other caused drift.

### Fix
**Whenever you change a threshold in `lib/health.sh`, immediately update `config/recommended.conf`.** They must be in perfect sync.

---

## 7. JSON Coercion Edge Cases (CLAUDE.md §3.8)

### What happened
- Leading zeros (`007`, `00123`) and numbers >15 digits were emitted as invalid JSON numbers.
- Literal string `"null"` was not coerced to JSON `null`.
- `*.name`, `*.company`, `*.technician`, and license identifier keys could become numbers if the value looked numeric.

### Fix (in `lib/json.sh`)
- Strict numeric pattern: `^-?(0|[1-9][0-9]{0,14})(\.[0-9]{1,6})?$` (no leading zeros, max 15 digits).
- Empty string or literal `null` → JSON `null`.
- Keys ending in `version`, `.ip`, `.domain`, `.hostname`, `.host` → always string.
- Force string for `*.name`, `*.company`, `*.technician`, license keys.
- Atomic write via temp file + `mv`.

---

## 8. STARTTLS Host Selection & Evidence

### What happened
The collector probed the first mail domain instead of the real mail host, causing false failures. No loopback fallback. No evidence recorded.

### Fix (in `collectors/dns/starttls.sh`)
- Target priority: `MAIL_HOSTNAME` → primary domain's MX target → never just the first mail domain.
- Loopback fallback with cleaned message (no duplicate `via host:port`).
- Record `smtp.starttls.trust = "not verified"` (probe never validates cert chain).
- Wall-clock budget `STARTTLS_BUDGET` (default 45 s) caps total probe time.

---

## 9. Health Semantics for Missing Data (CLAUDE.md §3.3)

### What happened
Missing/invalid settings (2FA, `watchdog.interval`, `monitor.enabled`) were defaulting to invented `pass` or arbitrary thresholds.

### Fix
- Missing data → `skip` or `warn`, **never** an invented `pass`.
- Admin Email unset → `critical` (human must set it).
- DIGEST-MD5 enabled → `critical` (weak legacy auth).
- Disk de-dup: deterministic sorted keys, numeric-safe comparisons.

---

## 10. Transport Payload Decision

### What happened
Ambiguity about whether to POST `health.json` (v1, flat) or `health.v2.json` (envelope).

### Fix (documented in `lib/transport.sh` and CHANGELOG)
**The posted payload is `health.json` (v1).** `health.v2.json` is a separate artifact for monitoring/mobile consumers and is not posted. Transport validates `MONITOR_URL` and file, uses `--connect-timeout`, `--max-time`, `--retry`, optional `MONITOR_AUTH_HEADER`, returns curl exit status.

---

## 11. Date Parsing — Never `date -d` on IceWarp Strings

### What happened
IceWarp `D-M-YY` strings (e.g., `27-10-26`) fed to `date -d` parsed as year 2027 / 2005 / 0009, producing false passes/failures.

### Fix (in `lib/common.sh`)
- Shared `norm_date` / `_days_ago` (only copy — do not redefine).
- Handles ISO, `D-M-YY`, `M/D/YYYY`.
- Unparseable date → empty output → callers treat as unknown (`warn`), **never** `0` or `999`.
- Date keys in `DATA[]` are ISO `YYYY-MM-DD`; keep original in `*_raw` sibling.

---

## 12. DSN Password Redaction

### What happened
Real MySQL installs exposed passwords in `health.json`, both PDFs, and the monitoring POST via `database.connection_string_raw`, `directory_cache.connection_string`, `backup.db.*.target_dsn`.

### Fix
- Wrap every DSN value in `redact_dsn` at collection time → `db;user;***;host;type;flag`.
- `lib/json.sh` re-applies redaction to any key matching `*dsn*|*connection_string*` as a safety net.

---

## 13. Check Registry Discipline (CLAUDE.md §3.11)

### What happened
Before the registry, pillar membership was maintained in hand-written arrays. Adding a check required editing multiple files.

### Fix
- **One registry:** `HEALTH_REGISTRY_LINES` in `lib/health.sh` — `id|pillar|title|flags`.
- Flags: `d` = detail only (not rolled up), `opt` = optional feature, `p` = the check is the pillar itself.
- Pillar roll-ups (`_pillar_rollup`), v2 `checks[]`, and `rolled_up` all read it.
- A new check = one registry line + one `_health_set <id> <result> <msg> <expected> <actual> <display>` call.
- **No hand-written pillar lists anywhere.**
- Validate `health.v2.json` against `docs/schema/health.v2.schema.json` after changes.

---

## 14. License Fallback (CLAUDE.md §3.6)

### What happened
Evaluation licenses with empty `C_License_TrialExpire` were assumed "perpetual".

### Fix
- If `C_License_TrialExpire` empty: **always** fallback to parsing `license.xml`.
- Try XML tags in order: `TrialExpire`, `TrialExpiration`, `Expire`, `ExpirationDate`, `LicenseExpiration`, `TrialDaysRemaining`, `DaysRemaining`.
- Calculate expiration from days remaining if only that is present.
- **Never** assume missing value means perpetual.

---

## 15. Docker Config Paths (CLAUDE.md §3.7)

### What happened
Collectors read `/opt/icewarp/config/license.xml` on bare metal but missed the Docker mount at `/opt/icewarp-data/config/license.xml`.

### Fix
- Collectors **MUST** check `/opt/icewarp-data/config/` first when running in Docker.
- Bare metal path: `/opt/icewarp/`.
- Container path: `/opt/icewarp-data/config/` (mounted from host `/opt/icewarp/config`).

---

## 16. Summary: Process Rules Going Forward

1. **Evidence before assertions** — verify with actual tool output, never hallucinate.
2. **One commit per task** — descriptive messages, never generic.
3. **Stage files explicitly** — never `git add -A` (tests/ is not gitignored).
4. **LF line endings on all `.sh` files** — never CRLF.
5. **PDF renderers hold no thresholds** — single source is `lib/health.sh` + `HEALTH_LABEL_MAP`.
6. **Configurator and Health Engine in perfect sync** — change both together.
7. **Check registry is canonical** — no parallel pillar lists.
8. **VM down = native Windows tools only** — use `git.exe`, `Read`/`Write`/`Edit` on `C:\` paths.
9. **Verify before push** — `git show HEAD -- <file>`, then `git ls-remote origin <branch>`.

---

*Recorded: 2026-11-02*  
*Branch: step3/health-registry-rollup*  
*Version: 0.7.3*