#!/bin/bash

# Checklist: "Enable System Backup", "Enable Database Backup",
# "Configure Archive Backup Settings", "Last Backup Date and Time"
#
# NOTE: this replaces the previous version of this file - it preserves the
# old filesystem-based keys (default path / last file mtime) and adds the
# tool.sh-backed auto-backup settings on top, per the project's stated
# priority order (tool.sh first, OS fallback last).

collector_run() {

    # --- existing filesystem-based checks (kept) ---
    collector_set "icewarp.backup.default" "${IW_BACKUP}"

    local LAST_FILE
    LAST_FILE="$(find "${IW_BACKUP}" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n1 | cut -d' ' -f2-)"
    collector_set "icewarp.backup.last_file" "${LAST_FILE:-${IW_BACKUP}/groupware.db}"

    if [ -n "$LAST_FILE" ] && [ -f "$LAST_FILE" ]; then
        collector_set "icewarp.backup.last_time" "$(date -r "$LAST_FILE" '+%F %T' 2>/dev/null)"
    fi

    # --- tool.sh auto-backup settings (new) ---
    collector_set "icewarp.backup.auto_enabled" "$(iw_get "C_System_Tools_AutoBackup_Enable" "" "" "")"
    collector_set "icewarp.backup.auto_target" "$(iw_get "C_System_Tools_AutoBackup_BackupTo" "" "" "")"
    collector_set "icewarp.backup.auto_delete_after_days" "$(iw_get "C_System_Tools_AutoBackup_DeleteAfter" "" "" "")"
    collector_set "icewarp.backup.extra_dirs" "$(iw_get "C_System_Tools_Backup_Dirs" "" "" "")"

}
