#!/bin/bash
# collectors/icewarp/backup.sh
# FIXED: Use correct keys from tool.sh (with c_ prefix)

collector_run() {
    if [ -n "${IW_TOOL:-}" ] && [ -x "$IW_TOOL" ]; then
        # --- System Backup ---
        # Backup enabled (c_system_tools_autobackup_enable)
        local BACKUP_ENABLED
        BACKUP_ENABLED="$(timeout 5 "$IW_TOOL" display system c_system_tools_autobackup_enable 2>/dev/null | awk -F': ' '{print $2}' | tr -d ' ')"
        if [ "$BACKUP_ENABLED" = "1" ] || [ "$BACKUP_ENABLED" = "true" ]; then
            DATA["icewarp.backup.auto_enabled"]="1"
        else
            DATA["icewarp.backup.auto_enabled"]="0"
        fi

        # Backup target path (c_system_tools_autobackup_backupto)
        local BACKUP_TARGET
        BACKUP_TARGET="$(timeout 5 "$IW_TOOL" display system c_system_tools_autobackup_backupto 2>/dev/null | awk -F': ' '{print $2}')"
        [ -n "$BACKUP_TARGET" ] && DATA["icewarp.backup.auto_target"]="$BACKUP_TARGET"

        # Delete older than days (c_system_tools_autobackup_deleteafter)
        local BACKUP_DELETE
        BACKUP_DELETE="$(timeout 5 "$IW_TOOL" display system c_system_tools_autobackup_deleteafter 2>/dev/null | awk -F': ' '{print $2}')"
        [ -n "$BACKUP_DELETE" ] && DATA["icewarp.backup.auto_delete_after_days"]="$BACKUP_DELETE"

        # Last backup file (from filesystem)
        local BACKUP_DIR="/opt/icewarp/backup"
        if [ -d "$BACKUP_DIR" ]; then
            local LAST_FILE
            LAST_FILE="$(timeout 5 find "$BACKUP_DIR" -type f -name "*.zip" -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -1 | awk '{print $2}')"
            if [ -n "$LAST_FILE" ]; then
                DATA["icewarp.backup.last_file"]="$LAST_FILE"
                DATA["icewarp.backup.last_time"]="$(date -r "$LAST_FILE" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
            fi
        fi

        # Backup emails option (c_system_tools_backup_emails)
        local BACKUP_EMAILS
        BACKUP_EMAILS="$(timeout 5 "$IW_TOOL" display system c_system_tools_backup_emails 2>/dev/null | awk -F': ' '{print $2}' | tr -d ' ')"
        if [ "$BACKUP_EMAILS" = "1" ] || [ "$BACKUP_EMAILS" = "true" ]; then
            DATA["backup.emails.enabled"]="1"
        else
            DATA["backup.emails.enabled"]="0"
        fi

        # ============================================================
        # Archive settings (c_system_tools_autoarchive_*)
        # ============================================================
        
        # Archive Active (c_system_tools_autoarchive_enable)
        local ARCHIVE_ACTIVE
        ARCHIVE_ACTIVE="$(timeout 5 "$IW_TOOL" display system c_system_tools_autoarchive_enable 2>/dev/null | awk -F': ' '{print $2}' | tr -d ' ')"
        if [ "$ARCHIVE_ACTIVE" = "1" ] || [ "$ARCHIVE_ACTIVE" = "true" ]; then
            DATA["archive.active"]="1"
        else
            DATA["archive.active"]="0"
        fi

        # Archive to directory (c_system_tools_autoarchive_path)
        local ARCHIVE_PATH
        ARCHIVE_PATH="$(timeout 5 "$IW_TOOL" display system c_system_tools_autoarchive_path 2>/dev/null | awk -F': ' '{print $2}')"
        [ -n "$ARCHIVE_PATH" ] && DATA["icewarp.archive.default"]="$ARCHIVE_PATH"

        # Integrate archive with IMAP folder (c_system_tools_autoarchive_imaparchive)
        local ARCHIVE_IMAP
        ARCHIVE_IMAP="$(timeout 5 "$IW_TOOL" display system c_system_tools_autoarchive_imaparchive 2>/dev/null | awk -F': ' '{print $2}' | tr -d ' ')"
        if [ "$ARCHIVE_IMAP" = "1" ] || [ "$ARCHIVE_IMAP" = "true" ]; then
            DATA["archive.integrate_with_imap"]="1"
        else
            DATA["archive.integrate_with_imap"]="0"
        fi

        # Do not archive spam (c_system_tools_autoarchive_donotspam)
        local ARCHIVE_DONOTSPAM
        ARCHIVE_DONOTSPAM="$(timeout 5 "$IW_TOOL" display system c_system_tools_autoarchive_donotspam 2>/dev/null | awk -F': ' '{print $2}' | tr -d ' ')"
        if [ "$ARCHIVE_DONOTSPAM" = "1" ] || [ "$ARCHIVE_DONOTSPAM" = "true" ]; then
            DATA["archive.do_not_archive_spam"]="1"
        else
            DATA["archive.do_not_archive_spam"]="0"
        fi

        # Archive Backup (deleted messages) - c_system_tools_autoarchive_backup_active
        local ARCHIVE_BACKUP_ACTIVE
        ARCHIVE_BACKUP_ACTIVE="$(timeout 5 "$IW_TOOL" display system c_system_tools_autoarchive_backup_active 2>/dev/null | awk -F': ' '{print $2}' | tr -d ' ')"
        if [ "$ARCHIVE_BACKUP_ACTIVE" = "1" ] || [ "$ARCHIVE_BACKUP_ACTIVE" = "true" ]; then
            DATA["archive.backup.active"]="1"
        else
            DATA["archive.backup.active"]="0"
        fi
    fi
}
