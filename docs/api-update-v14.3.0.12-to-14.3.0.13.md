# API Update Note: IceWarp 14.3.0.12 to 14.3.0.13

**Date:** 2026-10-26
**Scope:** API Reference Comparison (APIConst.pas, Windows side)
**Impact:** None on existing collectors

---

## Summary

IceWarp was upgraded from version **14.3.0.12** to **14.3.0.13**. The
supplied Windows-side `APIConst.pas` was added as `tool.v14.3.0.13.help` and
compared against `tool.v14.3.0.12.help`.

**Result:** No API-layer changes were detected. The two files are
byte-for-byte identical (same SHA-256), with 1,914 assignment lines
(1,892 API variables plus 22 constants) in both. No keys were added,
removed, renamed, or changed. No collector, health-rule, checklist, or report
modifications are required.

> **Verification note:** This conclusion depends on the supplied
> `APIConst.pas` genuinely coming from the 14.3.0.13 installation. Confirm the
> server file hash matches the value in [Source Verification](#source-verification)
> before relying on this note for a different installation.

---

## Comparison Overview

| Metric | Version 14.3.0.12 | Version 14.3.0.13 |
|---|---:|---:|
| File size | 267,707 bytes | 267,707 bytes |
| Lines | 2,721 | 2,721 |
| Assignment lines (previous note's method) | 1,914 | 1,914 |
| API variables | 1,892 | 1,892 |
| Constants in the constant block | 22 | 22 |
| New keys | - | 0 |
| Removed keys | - | 0 |
| Changed keys (name, ID, type, or description) | - | 0 |
| SHA-256 | `51ee7026...1287e5d` | `51ee7026...1287e5d` |

The previous update note counted every `name = value;` line and reported
1,914 total keys. This note uses the same total for comparability and also
separates the 22 constants (`API_ALL_VARS_MASK`, `S_OK`, and the `E_*` result
codes) from the 1,892 API variables.

---

## Source Verification

- Supplied source: `C:\Users\mrkashi\Desktop\apiconst.pas`
- Repository reference: `tool.v14.3.0.13.help`
- SHA-256:
  `51EE702640A3B08CC0AF77805E3D54E143709E91DCEEF190BF880DEF11287E5D`
- Encoding: ASCII, LF line endings, no BOM (the file starts with `//`).
- `Compare-Object` on the complete v12 and v13 files returns zero differences.

Windows PowerShell verification:

```powershell
Get-FileHash .\tool.v14.3.0.12.help, .\tool.v14.3.0.13.help -Algorithm SHA256

$v12 = Get-Content .\tool.v14.3.0.12.help
$v13 = Get-Content .\tool.v14.3.0.13.help
(Compare-Object $v12 $v13).Count
```

Expected result: two matching hashes and a count of `0`.

To confirm the file on the Windows server, adjust the IceWarp installation
path if necessary:

```powershell
Get-FileHash '<InstallDirectory>\API\Delphi\APIConst.pas' -Algorithm SHA256
```

If the server hash differs, replace `tool.v14.3.0.13.help` and rerun the
comparison. Do not assume this no-change result for a different build.

---

## Key-Set Comparison

The extraction method matches the previous note: each line matching
`^\s*[A-Za-z_]\w*\s*=` counts as one assignment. The comparison covered key
names, numeric IDs, declared types, and trailing descriptions.

| Check | Result |
|---|---|
| Key names present only in 14.3.0.13 | 0 |
| Key names present only in 14.3.0.12 | 0 |
| Renamed keys | 0 |
| Changed numeric IDs | 0 |
| Changed types or descriptions | 0 |
| Duplicate assignment names | 0 |

Windows PowerShell key comparison:

```powershell
$old = Get-Content .\tool.v14.3.0.12.help |
    Where-Object { $_ -match '^\s*[A-Za-z_]\w*\s*=' } |
    ForEach-Object { ($_ -split '=', 2)[0].Trim() } |
    Sort-Object -Unique

$new = Get-Content .\tool.v14.3.0.13.help |
    Where-Object { $_ -match '^\s*[A-Za-z_]\w*\s*=' } |
    ForEach-Object { ($_ -split '=', 2)[0].Trim() } |
    Sort-Object -Unique

Compare-Object $old $new
```

Expected result: no output.

---

## Windows-Specific Checks

The supplied file is the Windows-side reference. The following entries that
affect Windows behavior were checked and are unchanged:

| Key | Value | Finding |
|---|---|---|
| `C_OS` | `$1002` | `0 = Windows`, `1 = Linux`; Windows collectors still expect `0` |
| `C_Accounts_Policies_Auth_Schemes` | `$435` | Canonical SASL authentication key present |
| `C_Mail_Security_AuthScheme` | absent | Confirms the incorrect/legacy key is still not defined |
| `C_Accounts_Global_LDAP_UseWindowsDLL` | `$344` | Unchanged; marked `[NO EFFECT]` because Windows always uses the Windows LDAP library |
| `C_Accounts_Global_LDAP_UseNTLMAuth` | `$449` | Unchanged; depends on the Windows LDAP setting above |

Linux-only entries remain in the reference but are not used by the Windows
agent:

- `C_System_Adv_Ext_SSLSelfKillControlOnDecryptError` (`$71C`)
- `C_System_Adv_Exit_On_Signal` (`$499`)
- `C_AV_SentinelOne_Timeout` (`$791`)
- `C_System_LibreOfficeBinary` (`$6AD`)

No Windows-only keys were added or removed. A byte-level Windows-to-Linux
comparison was not performed because no Linux 14.3.0.13 `APIConst.pas` was
supplied. The platform-gated entries above are unchanged.

---

## Impact Analysis

- **Collectors:** No changes. All existing key names and IDs remain valid.
- **Health rules:** No changes.
- **Checklist:** The 113-item mapping remains based on the 14.3.0.12 API;
  the v1.14 label remains display-only.
- **Reports:** No changes.
- **Windows agent:** No changes. The new reference is available for future
  Windows collectors.
- **`tool.help`:** Not refreshed, because no 14.3.0.13 `tool.exe` search
  export was supplied. `tool.v14.3.0.13.help` is the `APIConst.pas`
  reference, not a `tool.sh` property listing.

---

## Conclusion

The IceWarp Health Agent is **fully compatible** with IceWarp version
**14.3.0.13**. The supplied API reference is identical to 14.3.0.12, so no
changes were required in any of the following:

- Collectors (`collectors/` and `windows/collectors/`)
- Health rules (`lib/health.sh`)
- Checklist definition (`config/checklist.conf.pdf`)
- Report generators (`lib/pdf.sh`, `lib/management_report.sh`)
- Windows configuration or collector contracts

---

## Files Updated in This Release

| File | Change |
|---|---|
| `tool.v14.3.0.13.help` | Added (14.3.0.13 `APIConst.pas`; byte-identical to 14.3.0.12) |
| `docs/api-update-v14.3.0.12-to-14.3.0.13.md` | Added (this note) |
| `docs/checklist-coverage.md` | Noted that the 14.3.0.13 API reference is unchanged |
| `docs/update-log.md` | Added activity row |
| `CHANGELOG.md` | Added API reference entry |

`tool.help` and the collector configuration were intentionally left unchanged
because the API did not change and no 14.3.0.13 `tool.sh` export was supplied.

---

## Reference Commands

PowerShell (Windows):

```powershell
Get-FileHash .\tool.v14.3.0.12.help, .\tool.v14.3.0.13.help -Algorithm SHA256
Compare-Object (Get-Content .\tool.v14.3.0.12.help) (Get-Content .\tool.v14.3.0.13.help)
```

POSIX shell (Linux):

```bash
grep -oP "^\s*\w+\s*=" tool.v14.3.0.12.help | sed 's/[[:space:]]*=//' | sort -u > /tmp/keys_v12.txt
grep -oP "^\s*\w+\s*=" tool.v14.3.0.13.help | sed 's/[[:space:]]*=//' | sort -u > /tmp/keys_v13.txt

comm -13 /tmp/keys_v12.txt /tmp/keys_v13.txt
comm -23 /tmp/keys_v12.txt /tmp/keys_v13.txt

diff -u tool.v14.3.0.12.help tool.v14.3.0.13.help
```
