# WORKFLOW

Repeatable run / verify / commit / push workflow for the IceWarp Health Agent repository.

---

## 0. Prerequisites

- Windows host with Git for Windows installed (`git.exe` on PATH).
- Linux agent VM may be unavailable — this workflow uses **native Windows commands only**.
- Repository root: `C:\Users\mrkashi\Documents\Default Project\icewarp-health-agent`
- Working branch: `step3/health-registry-rollup` (or `main` after merge)

---

## 1. Local Syntax & Static Checks (Windows PowerShell)

```powershell
# From an elevated or regular PowerShell prompt
cd "C:\Users\mrkashi\Documents\Default Project\icewarp-health-agent"

# 1a. Bash syntax check on all shell scripts (requires bash; use Git Bash if available)
# If Git Bash is at C:\Program Files\Git\bin\bash.exe:
& "C:\Program Files\Git\bin\bash.exe" -c "bash -n agent.sh lib/*.sh collectors/**/*.sh maintenance/*.sh tests/*.sh 2>&1"

# 1b. If shellcheck is installed (Chocolatey: choco install shellcheck)
shellcheck agent.sh lib/*.sh collectors/**/*.sh maintenance/*.sh tests/*.sh 2>&1

# 1c. Quick agent dry-run (no collectors, just load libs)
# Requires the Linux VM; skip if VM is down
# ./agent.sh --list
```

**Expected:** No syntax errors. `shellcheck` warnings are acceptable; errors must be fixed.

---

## 2. Full Agent Run (Linux VM — when available)

```bash
# On the lab IceWarp server (Linux)
cd /opt/icewarp-health-agent   # or wherever the repo is cloned

# Full run with console summary
./agent.sh --report --technician="Test Run" --company="Lab" --no-auto-update

# Verify outputs exist
ls -la output/health.json output/report.pdf output/management_report.pdf

# Quick sanity checks
jq '.health.summary' output/health.json
# Should show: total_checks, failed, warnings, overall, areas_assessed

# Page count (requires pdftotext / poppler-utils)
pdftotext output/report.pdf - | wc -l
# Rough heuristic: ~60-70 lines per page → ~16 pages = ~1000 lines
```

**Acceptance criteria:**
- `output/health.json` exists and is valid JSON (jq parses it).
- `health.summary.total_checks` ≥ 50 (registry checks, not pillars).
- `health.summary.areas_assessed` = 9 (pillars).
- `health.summary.overall` ∈ {pass, warn, fail}.
- `output/report.pdf` page count ≈ 16 (was 22 before ROW_H fix).
- `output/management_report.pdf` exists and opens.

---

## 3. Collector-Level Validation (Linux VM — when available)

```bash
# Run the validity checker (tests all 81 collectors + data validation)
./maintenance/collectors_validity_checker.sh

# Or test a single collector
./maintenance/collector_tester.sh collectors/dns/starttls.sh
```

**Expected:** All collectors PASS (or TIMEOUT for known slow ones). Data validation: ≥ 300 keys in `health.json`.

---

## 4. Test Suite (Linux VM — when available)

```bash
# Run all tests
./tests/run_tests.sh

# Run a single test case
./tests/run_tests.sh norm_date
./tests/run_tests.sh json_value
./tests/run_tests.sh health_rollup
./tests/run_tests.sh starttls
```

**Expected:** All tests pass. `tests/run_tests.sh` exits 0.

---

## 5. PDF Render Verification (Linux VM — when available)

```bash
# Extract text from both PDFs for inspection
./tests/render_pdfs.sh
# Creates tests/output/report.txt and tests/output/management_report.txt

# Check technical report structure
grep -n "Health Summary" tests/output/report.txt
grep -n "Appendix" tests/output/report.txt

# Check management report structure
grep -n "Executive Overview" tests/output/management_report.txt
grep -n "Score" tests/output/management_report.txt
```

**Expected:** Both PDFs render without errors. Text extraction yields readable content.

---

## 6. Git Commit (Windows PowerShell — always works)

```powershell
cd "C:\Users\mrkashi\Documents\Default Project\icewarp-health-agent"

# 6a. Check status
git status

# 6b. Stage files EXPLICITLY (never git add -A because tests/ is not gitignored)
# Example for version bump task:
git add VERSION config/agent.conf README.md CHANGELOG.md CLAUDE.md docs/update-log.md

# Example for documentation task:
git add LESSONS_LEARNED.md WORKFLOW.md TESTING_GUIDE.md

# 6c. Commit with descriptive message (one task = one commit)
git commit -m "chore: bump version to 0.7.3

- VERSION: 0.7.3
- config/agent.conf: AGENT_VERSION=0.7.3
- README.md: version badge and current version line
- CHANGELOG.md: add [0.7.3] section
- CLAUDE.md: header/footer version
- docs/update-log.md: record 0.7.2 commit hash, add 0.7.3 row"

# 6d. Verify commit diff
git show HEAD --stat
git show HEAD -- VERSION config/agent.conf README.md CHANGELOG.md CLAUDE.md docs/update-log.md
```

---

## 7. Git Push & Remote Verification (Windows PowerShell)

```powershell
# 7a. Push to the working branch
git push origin step3/health-registry-rollup

# 7b. Verify remote hash moved
git ls-remote origin step3/health-registry-rollup
# Should show the new commit hash (not the old 0200e463...)

# 7c. Optional: verify on GitHub web UI
# https://github.com/kashiparsavan/icewarp-health-agent/commits/step3/health-registry-rollup
```

**Expected:** Remote branch tip matches local HEAD.

---

## 8. Linux Server Fetch & Reset (when deploying to lab server)

```bash
# On the lab IceWarp server
cd /opt/icewarp-health-agent

# Fetch latest
git fetch origin

# Hard reset to the remote branch (discards any local drift)
git reset --hard origin/step3/health-registry-rollup

# Verify
git log -1 --oneline
# Should match the hash from git ls-remote

# Make agent.sh executable
chmod +x agent.sh maintenance/*.sh tests/*.sh

# Run validation
./agent.sh --report --technician="Deploy Test" --company="Lab" --no-auto-update
```

---

## 9. Merge to Main (separate step, after branch is stable)

```powershell
# On Windows host (or any machine with git)
cd "C:\Users\mrkashi\Documents\Default Project\icewarp-health-agent"

git checkout main
git pull origin main
git merge step3/health-registry-rollup --no-ff -m "Merge step3: health registry rollup, PDF fixes, STARTTLS, transport hardening"
git push origin main
```

**Note:** `AUTO_UPDATE_BRANCH=main` in `config/agent.conf` will not deliver 0.7.x until this merge happens. Pushing the feature branch makes its content real on the remote; the merge is a separate, deliberate step.

---

## 10. Post-Merge Version Tag (optional)

```powershell
git tag -a v0.7.3 -m "IceWarp Health Agent 0.7.3"
git push origin v0.7.3
```

---

## Quick Reference: File Paths

| Purpose | Windows Path | Linux Path |
|---------|--------------|------------|
| Repo root | `C:\Users\mrkashi\Documents\Default Project\icewarp-health-agent` | `/opt/icewarp-health-agent` (typical) |
| Git executable | `git.exe` (PATH) | `git` (PATH) |
| Bash (if needed) | `C:\Program Files\Git\bin\bash.exe` | `bash` (PATH) |
| Agent entry | `agent.sh` | `./agent.sh` |
| Outputs | `output\health.json` etc. | `output/health.json` etc. |
| Logs | `logs\auto_update.log` | `logs/auto_update.log` |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `bash -n` fails | CRLF line endings | `git config core.autocrlf false` + re-clone, or `dos2unix` on affected files |
| `git add -A` stages `tests/` | Not in `.gitignore` | Stage files explicitly (see §6) |
| VM won't start | `VM_DISK_SPACE_INSUFFICIENT` | Use Windows `git.exe` + native file ops; defer Linux tests |
| `agent.sh` permission denied | Not executable | `chmod +x agent.sh` on Linux |
| `health.json` truncated | Concurrent read during atomic write | Retry; write uses temp+mv |
| Auto-update skipped | Dirty working tree | Commit or stash changes before run |

---

*Documented: 2026-11-02*  
*Branch: step3/health-registry-rollup*  
*Version: 0.7.3*