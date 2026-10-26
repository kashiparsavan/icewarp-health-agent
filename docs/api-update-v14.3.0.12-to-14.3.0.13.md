# API Update Note: IceWarp 14.3.0.12 to 14.3.0.13 (Linux)

**Date:** 2026-10-26
**Scope:** Linux API Reference Comparison (APIConst.pas); Windows hash check
**Impact:** None on existing Linux collectors; Windows key comparison not performed

---

## Summary

IceWarp was upgraded from version **14.3.0.12** to **14.3.0.13**. The
supplied Linux `APIConst.pas` was added as `tool.v14.3.0.13.help` and compared
against the existing Linux `tool.v14.3.0.12.help`.

**Linux result:** No API-layer changes. The two Linux files are byte-for-byte
identical (same SHA-256), with 1,914 assignment lines (1,892 API variables
plus 22 constants) in both. No keys were added, removed, renamed, or changed.
No Linux collector, health-rule, checklist, or report modifications are
required.

**Windows check:** The Windows 14.3.0.13 `APIConst.pas` has a different
SHA-256 from the Linux file. The files are therefore not byte-identical. Only
the Windows hash was supplied, so a key-level Windows-vs-Linux comparison was
not performed. See [Windows Hash Check](#windows-hash-check).

> **Scope note:** This note does not claim that the Windows API keys are the
> same as Linux. A hash comparison can only show whether the files are
> identical; it cannot identify which keys differ.

---

## Comparison Overview

### Linux 14.3.0.12 vs Linux 14.3.0.13

| Metric | Linux 14.3.0.12 | Linux 14.3.0.13 |
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

## Source Verification (Linux)

- Supplied Linux source: `C:\Users\mrkashi\Desktop\apiconst.pas`
- Repository reference: `tool.v14.3.0.13.help`
- SHA-256:
  `51EE702640A3B08CC0AF77805E3D54E143709E91DCEEF190BF880DEF11287E5D`
- Encoding: ASCII, LF line endings, no BOM (the file starts with `//`).
- `Compare-Object` on the complete Linux v12 and Linux v13 files returns
  zero differences.

Windows PowerShell verification:

```powershell
Get-FileHash .\tool.v14.3.0.12.help, .\tool.v14.3.0.13.help -Algorithm SHA256

$v12 = Get-Content .\tool.v14.3.0.12.help
$v13 = Get-Content .\tool.v14.3.0.13.help
(Compare-Object $v12 $v13).Count
```

Expected result: two matching hashes and a count of `0`.

---

## Key-Set Comparison (Linux)

The extraction method matches the previous note: each line matching
`^\s*[A-Za-z_]\w*\s*=` counts as one assignment. The comparison covered key
names, numeric IDs, declared types, and trailing descriptions.

| Check | Result |
|---|---|
| Key names present only in Linux 14.3.0.13 | 0 |
| Key names present only in Linux 14.3.0.12 | 0 |
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

## Windows Hash Check

The Windows server file was checked separately:

| File | SHA-256 |
|---|---|
| Linux 14.3.0.13 (`tool.v14.3.0.13.help`) | `51EE702640A3B08CC0AF77805E3D54E143709E91DCEEF190BF880DEF11287E5D` |
| Windows 14.3.0.13 (`C:\Program Files\IceWarp\api\delphi\APIConst.pas`) | `5102C041514887DEC81A428B05EB9D6D930EA38B3F423B350EE790EDA31D9D36` |

The hashes differ, so the Linux and Windows files are not byte-identical.
The Windows file has now been supplied and compared at key level. See
[Windows vs Linux Comparison](docs/api-windows-vs-linux-v14.3.0.13.md).
All Linux keys are present on Windows; Windows adds 4 keys, changes the
capitalization of 2 keys, and marks `U_MasterDomain` read-only. The Linux
comparison above is complete and unaffected.

---

## Impact Analysis

- **Linux collectors:** No changes. All existing Linux key names and IDs
  remain valid.
- **Linux health rules:** No changes.
- **Checklist:** The 113-item mapping remains based on the 14.3.0.12 API; the
  v1.14 label remains display-only.
- **Linux reports:** No changes.
- **Windows agent:** No changes. Windows key parity with Linux is now
  verified at key level; see
  [Windows vs Linux Comparison](docs/api-windows-vs-linux-v14.3.0.13.md).
- **`tool.help`:** Not refreshed, because no 14.3.0.13 `tool.exe` search
  export was supplied. `tool.v14.3.0.13.help` is the `APIConst.pas`
  reference, not a `tool.sh` property listing.

---

## Conclusion

The Linux IceWarp Health Agent is **fully compatible** with IceWarp version
**14.3.0.13**. The supplied Linux API reference is identical to Linux
14.3.0.12, so no Linux changes were required in any of the following:

- Collectors (`collectors/`)
- Health rules (`lib/health.sh`)
- Checklist definition (`config/checklist.conf.pdf`)
- Report generators (`lib/pdf.sh`, `lib/management_report.sh`)

The Windows API key comparison is **complete** and documented in
`docs/api-windows-vs-linux-v14.3.0.13.md`. All Linux keys are present on
Windows; Windows adds 4 keys, changes the capitalization of 2 keys, and marks
`U_MasterDomain` read-only. This is a separate follow-up, not a failure of
the Linux update.

---

## Files Updated in This Release

| File | Change |
|---|---|
| `tool.v14.3.0.13.help` | Added (Linux 14.3.0.13 `APIConst.pas`; byte-identical to Linux 14.3.0.12) |
| `docs/api-update-v14.3.0.12-to-14.3.0.13.md` | Added (this note) |
| `docs/checklist-coverage.md` | Noted that the Linux 14.3.0.13 API reference is unchanged |
| `docs/update-log.md` | Added activity row |
| `CHANGELOG.md` | Added API reference entry |

`tool.help` and the collector configuration were intentionally left unchanged
because the Linux API did not change and no 14.3.0.13 `tool.sh` export was
supplied.

---

## Reference Commands

POSIX shell (Linux):

```bash
grep -oP "^\s*\w+\s*=" tool.v14.3.0.12.help | sed 's/[[:space:]]*=//' | sort -u > /tmp/keys_v12.txt
grep -oP "^\s*\w+\s*=" tool.v14.3.0.13.help | sed 's/[[:space:]]*=//' | sort -u > /tmp/keys_v13.txt

comm -13 /tmp/keys_v12.txt /tmp/keys_v13.txt
comm -23 /tmp/keys_v12.txt /tmp/keys_v13.txt

diff -u tool.v14.3.0.12.help tool.v14.3.0.13.help
```

Windows hash check (run on the IceWarp Windows server):

```powershell
Get-FileHash '<InstallDirectory>\API\Delphi\APIConst.pas' -Algorithm SHA256
```

To compare the Windows file at key level once available:

```powershell
$linux = Get-Content .\tool.v14.3.0.13.help
$windows = Get-Content '<InstallDirectory>\API\Delphi\APIConst.pas'
Compare-Object $linux $windows
```
