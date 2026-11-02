# TESTING_GUIDE

How to run tests, verify outputs, and confirm correctness for the IceWarp Health Agent.

---

## 1. Static Analysis (Windows PowerShell — always available)

### 1.1 Bash Syntax Check

```powershell
cd "C:\Users\mrkashi\Documents\Default Project\icewarp-health-agent"

# Requires Git Bash (bash.exe)
& "C:\Program Files\Git\bin\bash.exe" -c "bash -n agent.sh lib/*.sh collectors/**/*.sh maintenance/*.sh tests/*.sh 2>&1"
```

**Expected:** No output = no syntax errors. Any output = fix the reported line.

### 1.2 ShellCheck (if installed)

```powershell
# Install: choco install shellcheck
shellcheck agent.sh lib/*.sh collectors/**/*.sh maintenance/*.sh tests/*.sh 2>&1
```

**Expected:** Zero errors. Warnings (SC2034, SC2155, etc.) are acceptable but should be reviewed.

### 1.3 Line Ending Check

```powershell
# All .sh files must be LF only
& "C:\Program Files\Git\bin\bash.exe" -c "find . -name '*.sh' -exec file {} \; | grep CRLF"
```

**Expected:** No output. If files show CRLF, run `dos2unix` or re-clone with `core.autocrlf=false`.

---

## 2. Unit Tests (Linux VM required)

### 2.1 Run All Tests

```bash
cd /opt/icewarp-health-agent
./tests/run_tests.sh
```

**Expected output:**
```
========================================
tests: 4 passed, 0 failed
========================================
```

Exit code 0 = success.

### 2.2 Individual Test Cases

```bash
# Date normalization (lib/common.sh)
./tests/run_tests.sh norm_date

# JSON value coercion (lib/json.sh)
./tests/run_tests.sh json_value

# Health summary roll-up (lib/health.sh)
./tests/run_tests.sh health_rollup

# STARTTLS collector with fake SMTP server
./tests/run_tests.sh starttls
```

**Each test:** Exits 0 on pass, non-zero on fail with `>>> test_NAME FAILED (exit N)`.

### 2.3 Test Fixtures

Located in `tests/fixtures/`:
- `healthy.dat` — sample `DATA[]` for a healthy server
- `disk_full.dat` — sample with disk pressure
- `starttls_delayed_banner.dat` — fake SMTP banner delayed 7s

---

## 3. Collector Validity Checker (Linux VM required)

### 3.1 Full Validation Suite

```bash
./maintenance/collectors_validity_checker.sh
```

**What it does:**
1. Runs all 81 collectors individually (30s timeout each)
2. Runs full agent to produce `output/health.json`
3. Validates JSON has ≥ 300 keys

**Expected:**
```
========================================
Collector Execution Summary
========================================
Total collectors : 81
Passed           : 81
Failed           : 0
Timed out        : 0
========================================

✅ Data validation PASSED
```

### 3.2 Single Collector Test

```bash
./maintenance/collector_tester.sh collectors/dns/starttls.sh
```

**Output:** Collector's `DATA[]` key=value pairs + exit code.

---

## 4. Full Agent Run Verification (Linux VM required)

### 4.1 Standard Run

```bash
./agent.sh --report --technician="Test Run" --company="Lab" --no-auto-update
```

**Console output should include:**
- Collector discovery count (81)
- Health summary with pillars
- PDF generation confirmation
- JSON write confirmation

### 4.2 Verify health.json Structure

```bash
# Summary block
jq '.health.summary' output/health.json
```

**Expected keys:**
```json
{
  "total_checks": 60,       // registry checks (not pillars!)
  "failed": 0,              // fail + critical count
  "warnings": 2,            // warn count
  "overall": "pass",        // pass | warn | fail
  "areas_assessed": 9       // pillars (operational areas)
}
```

**Critical assertions:**
- `total_checks` ≥ 50 (was 9 when counting pillars — bug fixed in 0.7.3)
- `areas_assessed` == 9 (always 9 pillars)
- `overall` ∈ ["pass", "warn", "fail"]
- No `null` values for required keys

### 4.3 Verify Key Health Checks

```bash
# Intrusion Prevention
jq '.health.intrusion.*' output/health.json

# Admin Email
jq '.health.admin_email' output/health.json

# TLS Certificate
jq '.health.tls_certificate' output/health.json

# Backup
jq '.health.backup_*' output/health.json

# Watchdog (4 services)
jq '.health.watchdog_*' output/health.json
```

Each should have `.result` ∈ ["pass", "warn", "fail", "critical", "skip"] and `.message`.

### 4.4 Verify JSON Validity & Type Coercion

```bash
# Full parse test
jq empty output/health.json && echo "VALID JSON"

# Check numeric coercion (should be unquoted numbers)
jq 'to_entries[] | select(.value | type=="number") | .key' output/health.json | head -20

# Check boolean coercion (should be unquoted true/false)
jq 'to_entries[] | select(.value | type=="boolean") | .key' output/health.json

# Check null coercion
jq 'to_entries[] | select(.value == null) | .key' output/health.json

# Check forced-string keys
jq '.general.os.version' output/health.json      # should be "9.8" (string)
jq '.general.company_name' output/health.json    # should be string even if numeric
```

**Expected:**
- All version/ip/domain/hostname/host keys → quoted strings
- `*.name`, `*.company`, `*.technician` → quoted strings
- Numeric metrics → unquoted numbers
- Booleans → unquoted true/false
- Empty/missing → null

---

## 5. PDF Report Verification (Linux VM required)

### 5.1 Technical Report (`output/report.pdf`)

```bash
# Page count (requires poppler-utils: pdftotext)
pdftotext output/report.pdf - | wc -l
# Heuristic: ~65 lines/page → 16 pages ≈ 1040 lines

# Or use pdfinfo
pdfinfo output/report.pdf | grep Pages
```

**Expected:** **16 pages** (was 22 before ROW_H=20 fix).

### 5.2 Management Report (`output/management_report.pdf`)

```bash
pdfinfo output/management_report.pdf | grep Pages
```

**Expected:** 3-5 pages (cover + scorecards + actions).

### 5.3 Content Extraction for Inspection

```bash
# Extract text
pdftotext output/report.pdf tests/output/report.txt
pdftotext output/management_report.pdf tests/output/management_report.txt

# Verify Health Summary section exists
grep -n "Health Summary" tests/output/report.txt

# Verify Appendix structure
grep -n "Appendix" tests/output/report.txt

# Verify management report cover score
grep -n "Score" tests/output/management_report.txt

# Verify no truncated Value columns (was 34 chars, now 46)
grep "Total(KB)=" tests/output/report.txt
grep "Total(GB)=" tests/output/report.txt
```

**Expected:**
- Health Summary renders all 9 pillars with correct status
- Appendix tables have repeating headers on page breaks
- Value column shows full `Total(KB)=<n> / Available KB=<n>` (not truncated)
- Management cover score matches `health.summary.overall`
- Status bars: remainder is muted track color (not INFO/N-A color)

---

## 6. Health Summary Counting Verification (Critical)

The 0.7.3 fix changed `health.summary.failed` from counting **pillars** to counting **registry checks**. Verify:

```bash
# Count registry checks with non-skip results
jq -r '.health | to_entries[] | select(.key | startswith("health.") and (.value | has("result"))) | .value.result' output/health.json | \
  grep -v "^skip$" | wc -l
# Should match health.summary.total_checks

# Count fail/critical
jq -r '.health | to_entries[] | select(.key | startswith("health.") and (.value | has("result"))) | .value.result' output/health.json | \
  grep -E "^(fail|critical)$" | wc -l
# Should match health.summary.failed

# Count warn
jq -r '.health | to_entries[] | select(.key | startswith("health.") and (.value | has("result"))) | .value.result' output/health.json | \
  grep "^warn$" | wc -l
# Should match health.summary.warnings
```

**Before 0.7.3 (buggy):**
- `total_checks` = 9 (pillars)
- `failed` = 1 (pillars with any failure)

**After 0.7.3 (fixed):**
- `total_checks` = ~60 (registry entries)
- `failed` = actual count of fail+critical checks
- `areas_assessed` = 9 (pillars, unchanged)

---

## 7. Configurator Dry-Run Verification

```bash
./agent.sh --config --technician="Test" --company="Lab" --no-auto-update
```

**Expected:**
- No `key not found` lines
- Output shows recommended vs current for each key in `config/recommended.conf`
- Exit code 0

---

## 8. Transport Test (if MONITOR_URL configured)

```bash
# Set test endpoint
export MONITOR_URL="https://httpbin.org/post"
export SEND_DATA=1

./agent.sh --report --technician="Transport Test" --company="Lab" --no-auto-update
```

**Verify:** `lib/transport.sh` returns curl exit code 0. Check httpbin response for posted JSON.

---

## 9. Auto-Update Test

```bash
# Check for updates without applying
./agent.sh --check-update --no-auto-update

# Force update check (override config)
./agent.sh --auto-update --technician="Test" --company="Lab"
```

**Expected:** Logs to `logs/auto_update.log` with pipe-delimited format.

---

## 10. Acceptance Checklist for Release

| Check | Command | Pass Criteria |
|-------|---------|---------------|
| Syntax | `bash -n ...` | No errors |
| ShellCheck | `shellcheck ...` | No errors |
| Line endings | `file *.sh \| grep CRLF` | No output |
| Unit tests | `./tests/run_tests.sh` | 4 passed, 0 failed |
| Collectors | `./maintenance/collectors_validity_checker.sh` | 81 passed, ≥300 keys |
| Agent run | `./agent.sh --report` | Exit 0, all outputs created |
| health.json valid | `jq empty output/health.json` | Exit 0 |
| total_checks ≥ 50 | `jq .health.summary.total_checks` | ≥ 50 |
| areas_assessed = 9 | `jq .health.summary.areas_assessed` | == 9 |
| failed = fail+critical count | (see §6) | Matches manual count |
| report.pdf pages | `pdfinfo ... \| grep Pages` | 16 |
| mgmt_report.pdf pages | `pdfinfo ... \| grep Pages` | 3-5 |
| Configurator | `./agent.sh --config` | No "key not found" |
| JSON coercion | (see §4.4) | Types correct |

---

## 11. Windows-Only Quick Validation (when VM is down)

```powershell
cd "C:\Users\mrkashi\Documents\Default Project\icewarp-health-agent"

# 1. Syntax check via Git Bash
& "C:\Program Files\Git\bin\bash.exe" -c "bash -n agent.sh lib/*.sh collectors/**/*.sh maintenance/*.sh tests/*.sh"

# 2. ShellCheck (if installed)
shellcheck agent.sh lib/*.sh collectors/**/*.sh maintenance/*.sh tests/*.sh

# 3. Line endings
& "C:\Program Files\Git\bin\bash.exe" -c "find . -name '*.sh' -exec file {} \; | grep CRLF"

# 4. Verify version consistency
cat VERSION
# Should match config/agent.conf AGENT_VERSION, README.md badge, CLAUDE.md footer

# 5. Git status (no uncommitted drift)
git status
# Should be clean or show only intentional staged changes
```

---

## 12. Common Failure Patterns & Fixes

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `bash -n` error on `collectors/**/*.sh` | Glob not expanded in PowerShell | Use Git Bash: `bash -c "bash -n collectors/**/*.sh"` |
| `health.json` parse error | Truncated read during atomic write | Re-run agent; write uses temp+mv |
| `total_checks` = 9 | Old pillar-counting code | Update to 0.7.3+ (registry-based) |
| PDF generation fails | `_pdf_text_trunc` MAXC… typo | Fixed in 0.7.2 (`MAXCHARS`) |
| STARTTLS false fail | Probe targets wrong host | Fixed in 0.7.2 (MAIL_HOSTNAME → MX) |
| Configurator "key not found" | Guessed property names | Use canonical `tool.help` keys (0.5.0+) |
| DSN password in JSON | Missing `redact_dsn` call | Wrap at collection + json.sh safety net |

---

*Documented: 2026-11-02*  
*Branch: step3/health-registry-rollup*  
*Version: 0.7.3*