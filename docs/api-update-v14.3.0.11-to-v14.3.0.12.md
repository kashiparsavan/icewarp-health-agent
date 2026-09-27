# API Update Note: IceWarp 14.3.0.11 to 14.3.0.12

**Date:** 2026-09-27
**Scope:** API Reference Comparison (APIconst.pas)
**Impact:** None on existing collectors

---

## Summary

IceWarp was upgraded from version **14.3.0.11** to **14.3.0.12** on the
production mail server. The full API reference (APIconst.pas) was
re-extracted and compared against the previous version.

**Result:** API changes are negligible. Only one key was removed and no
new keys were added. The IceWarp Health Agent is fully compatible with
version 14.3.0.12 and no collector modifications are required.

---

## Comparison Overview

| Metric | Version 14.3.0.11 | Version 14.3.0.12 |
|---|---|---|
| Total API keys | 1915 | 1914 |
| New keys | - | 0 |
| Removed keys | - | 1 (U_UserChatPush) |

---

## Removed Key Analysis

### U_UserChatPush

    U_UserChatPush = $7CE;  // Bool
    // Tells if the push service is enabled for user chat messages

**What it was:**
A user-level variable (prefix U_) indicating whether the push service
was enabled for user chat messages.

**Relevance to this project:**
None. All collectors in this project primarily use system-level
variables (prefix c_). The removed key belongs to the user-level
namespace and does not appear in any collector, health rule, or
checklist entry.

**Verification:**

    grep -ri "UserChatPush" /root/iceauto/

Expected output: empty.

---

## Conclusion

The IceWarp Health Agent is **fully compatible** with IceWarp version
**14.3.0.12**. No changes were required in any of the following:

- Collectors (collectors/)
- Health rules (lib/health.sh)
- Checklist definition (config/checklist.conf.pdf)
- Report generators (lib/pdf.sh, lib/management_report.sh)

---

## Files Updated in This Release

| File | Change |
|---|---|
| tool.v14.3.0.12.help | Added (new API reference for 14.3.0.12) |
| tool.v14.3.0.11.help | Renamed from tool.v4.11.help for clarity |
| tool.help | Refreshed with latest tool.sh search output |

---

## Reference Commands

For future API updates, the following commands can be used to compare
two API reference versions:

    grep -oP "^\s*\w+\s*=" tool.v14.3.0.11.help | sed 's/[[:space:]]*=//' | sort -u > /tmp/keys_old.txt
    grep -oP "^\s*\w+\s*=" tool.v14.3.0.12.help | sed 's/[[:space:]]*=//' | sort -u > /tmp/keys_new.txt

    comm -13 /tmp/keys_old.txt /tmp/keys_new.txt

    comm -23 /tmp/keys_old.txt /tmp/keys_new.txt

    diff tool.v14.3.0.11.help tool.v14.3.0.12.help

