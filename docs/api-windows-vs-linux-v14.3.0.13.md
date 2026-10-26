# Windows vs Linux API Reference Comparison: IceWarp 14.3.0.13

**Date:** 2026-10-26
**Scope:** `APIConst.pas` key, ID, type, description, and read-only comparison
**Impact:** No changes required to the current Linux or Windows collectors

---

## Summary

The Windows 14.3.0.13 `APIConst.pas` was added as
`tool.v14.3.0.13.windows.help` and compared with the Linux reference
`tool.v14.3.0.13.help`.

**Result:** The two platform references are very close at the API-key level.

- Every Linux key is present on Windows when names are matched
  case-insensitively: **0 Linux-only keys**.
- Windows adds **4 API variables** that are not in the Linux reference.
- **2 keys differ only in capitalization**: `U_GROUPS` → `U_Groups` and
  `U_GROUPSLIST` → `U_GroupsList`.
- **1 description/read-only change**: `U_MasterDomain` is `String` on Linux
  and `String [R]` on Windows. Its ID is unchanged.
- For all common keys, **IDs, values, and types are unchanged**.
- Neither file has duplicate IDs.
- The 22 constants at the top of the file are identical.

The Windows reference is required for Windows collector work, but it does not
replace the Linux reference. Both should be kept.

---

## Source Files

| Platform | Repository file | Source size | SHA-256 | Line endings |
|---|---|---:|---|---|
| Linux | `tool.v14.3.0.13.help` | 267,707 bytes | `51EE702640A3B08CC0AF77805E3D54E143709E91DCEEF190BF880DEF11287E5D` | LF |
| Windows | `tool.v14.3.0.13.windows.help` | 271,176 bytes | `5102C041514887DEC81A428B05EB9D6D930EA38B3F423B350EE790EDA31D9D36` | CRLF |

The Windows hash above is for the file as copied from the server. Git's
`text=auto eol=lf` rule normalizes the committed copy to LF; the normalized
content is 268,449 bytes with SHA-256
`BEEC2166C668E3247BAE623CD0DA7623A7F6E4480947F539F4DFBF2081F8DF1B`.
The key comparison is unaffected by line endings.

---

## Comparison Overview

| Check | Result |
|---|---|
| Linux assignments | 1,914 (1,892 API variables + 22 constants) |
| Windows assignments | 1,918 (1,896 API variables + 22 constants) |
| Exact common key names | 1,912 |
| Case-insensitive common keys | 1,914 |
| Linux keys missing on Windows | 0 |
| Genuinely new Windows-only keys | 4 |
| Case-only renames | 2 |
| Changed IDs for common keys | 0 |
| Changed values for common keys | 0 |
| Changed types for common keys | 0 |
| Changed descriptions for common keys | 1 (`U_MasterDomain`) |
| Duplicate IDs | 0 in both files |

The previous Linux update note counted 1,914 assignment lines for Linux. This
document uses the same counting method: every `name = value;` line, including
the 22 constants.

---

## Windows-Only Keys

These keys are present in the Windows reference but not in the Linux
reference.

| Key | ID | Type | Description | Used by current collectors |
|---|---|---|---|---|
| `C_API_DomainList_DefaultLimit` | `$8A7` | Int | Default number of domains requested by `GetDomainsInfoList` API call when count is not set | No |
| `U_MailingLists` | `$8A8` | String | List of mailing lists where the user is a member (including rights), read only, computed online | No |
| `U_MailingListsList` | `$8A9` | String | List of mailing lists where the user is a member, including all combinations of aliases/domain aliases, read only, computed online | No |
| `U_SlaveDomain` | `$8AD` | String [R] | User's domain, empty if it is the master of a domain cluster | No |

None of these keys appears in the current Linux collectors, health rules, or
the 113-item checklist. They do not require checklist changes.

The Windows file also updates the trailing `// Last Used ID:` comment from
`$8A4 U_2F_POLICY` to `$8AD U_SlaveDomain`. This is a file-maintenance
comment, not an API variable.

---

## Case-Only Changes

These keys have the same IDs and descriptions but different capitalization.

| Linux spelling | Windows spelling | ID | Description |
|---|---|---|---|
| `U_GROUPS` | `U_Groups` | `$46D` | List of groups where the user is a member, read only, computed online |
| `U_GROUPSLIST` | `U_GroupsList` | `$494` | List of groups where the user is a member, including all combinations of aliases/domain aliases, read only, computed online |

The Linux `tool.help` property listing already shows these names in lowercase
(`u_groups`, `u_groupslist`), so property lookup appears to be
case-insensitive. Use the Windows spelling in Windows-specific code and
documentation. No current collector uses these keys.

---

## Read-Only Change

| Key | Linux | Windows | ID | Description |
|---|---|---|---|---|
| `U_MasterDomain` | `String` | `String [R]` | `$731` | Master of domain cluster of the user |

On Windows, `U_MasterDomain` is explicitly read-only. No current collector
writes to it. If a future Windows collector needs this value, it should only
read it.

---

## Common-Key Checks

The following platform-relevant entries are present and unchanged:

| Key | Value | Linux | Windows |
|---|---|---|---|
| `C_OS` | `$1002` | `0 = Windows`, `1 = Linux` | `0 = Windows`, `1 = Linux` |
| `C_Accounts_Policies_Auth_Schemes` | `$435` | Present | Present |
| `C_Mail_Security_AuthScheme` | - | Absent | Absent |
| 22 constants in the constant block | - | Present | Identical |

No duplicate IDs were found in either reference. All common keys have the
same IDs, values, and declared types; the only common-key description change
is the `[R]` flag on `U_MasterDomain`.

---

## Porting Implications for Windows Collectors

1. **Yes, use the Windows reference.** `tool.v14.3.0.13.windows.help` is the
   authoritative Windows-side list of key names, IDs, types, and read-only
   flags. Use it when writing or reviewing Windows collectors.
2. **Do not replace the Linux reference.** Keep `tool.v14.3.0.13.help` for
   Linux and `tool.v14.3.0.13.windows.help` for Windows.
3. **Most key names carry over directly.** No Linux key is missing on Windows,
   so the existing collector key set does not need platform-specific
   replacements.
4. **Use the Windows spelling for the two renamed keys.** Prefer
   `U_Groups` / `U_GroupsList` in Windows code, even if `tool.exe` accepts
   other casing.
5. **Treat `U_MasterDomain` as read-only on Windows.**
6. **The 4 Windows-only keys are optional for the current checklist.** They
   are available for future Windows-specific checks but are not required by
   the existing 113 items.
7. **The API reference is not a substitute for live validation.** Windows
   `tool.exe` output formatting, value semantics, service names, and
   Windows-only behavior still need to be verified on the lab server.
8. **No Windows `tool.help` export was supplied.** The `APIConst.pas`
   reference is authoritative for key definitions, but a Windows `tool.exe`
   search/list export is still needed to validate the property listing
   behavior.

---

## Verification Commands

Windows PowerShell:

```powershell
Get-Content .\tool.v14.3.0.13.help |
    Where-Object { $_ -match '^\s*[A-Za-z_]\w*\s*=' } |
    ForEach-Object { ($_ -split '=', 2)[0].Trim() } |
    Sort-Object -Unique > $env:TEMP\linux-keys.txt

Get-Content .\tool.v14.3.0.13.windows.help |
    Where-Object { $_ -match '^\s*[A-Za-z_]\w*\s*=' } |
    ForEach-Object { ($_ -split '=', 2)[0].Trim() } |
    Sort-Object -Unique > $env:TEMP\windows-keys.txt

Compare-Object (Get-Content $env:TEMP\linux-keys.txt) `
               (Get-Content $env:TEMP\windows-keys.txt) -CaseSensitive
```

Expected: the 4 Windows-only keys, the 2 case-only pairs, and no other
differences.

Full content-line comparison (line endings are ignored by `Get-Content`):

```powershell
Compare-Object (Get-Content .\tool.v14.3.0.13.help) `
               (Get-Content .\tool.v14.3.0.13.windows.help)
```

Expected: the 4 new key lines, the 2 capitalization changes, the
`U_MasterDomain` description change, and the `Last Used ID` comment change.

---

## Files Updated in This Release

| File | Change |
|---|---|
| `tool.v14.3.0.13.windows.help` | Added (Windows 14.3.0.13 `APIConst.pas`) |
| `docs/api-windows-vs-linux-v14.3.0.13.md` | Added (this comparison) |
| `docs/api-update-v14.3.0.12-to-14.3.0.13.md` | Linked to this Windows comparison |
| `windows/README.md` | Added the Windows API reference note |
| `docs/checklist-coverage.md` | Recorded that the Windows differences do not affect the current 113-item checklist |
| `docs/update-log.md` | Added activity row |
| `CHANGELOG.md` | Added Windows API reference entry |

---

## Conclusion

The Windows and Linux 14.3.0.13 API references are compatible at the key
level. All Linux keys exist on Windows; Windows adds 4 keys, changes the
capitalization of 2 keys, and marks `U_MasterDomain` read-only. None of these
differences affects the current 113-item checklist or the existing Linux
collectors.

The Windows reference is needed for the Windows collector rewrite, but live
`tool.exe` validation remains the next step.
