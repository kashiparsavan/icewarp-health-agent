#!/bin/bash
# collectors/icewarp/backup.sh

collector_run() {
    if [ -n "${IW_TOOL:-}" ] && [ -x "$IW_TOOL" ]; then
        # Backup enabled (c_system_tools_backup_enable for v9)
        local BACKUP_ENABLED
        BACKUP_ENABLED="$(timeout 5 "$IW_TOOL" display system c_system_tools_backup_enable 2>/dev/null | awk -F': ' '{print $2}')"
        if [ "$BACKUP_ENABLED" = "1" ]; then
            DATA["icewarp.backup.auto_enabled"]="1"
        else
            DATA["icewarp.backup.auto_enabled"]="0"
        fi

        # Backup target path
        local BACKUP_TARGET
        BACKUP_TARGET="$(timeout 5 "$IW_TOOL" display system c_system_tools_backup_target 2>/dev/null | awk -F': ' '{print $2}')"
        [ -n "$BACKUP_TARGET" ] && DATA["icewarp.backup.auto_target"]="$BACKUP_TARGET"

        # Delete older than days
        local BACKUP_DELETE
        BACKUP_DELETE="$(timeout 5 "$IW_TOOL" display system c_system_tools_backup_deleteolderthan 2>/dev/null | awk -F': ' '{print $2}')"
        [ -n "$BACKUP_DELETE" ] && DATA["icewarp.backup.auto_delete_after_days"]="$BACKUP_DELETE"

        # Last backup file
        local BACKUP_DIR="/opt/icewarp/backup"
        if [ -d "$BACKUP_DIR" ]; then
            local LAST_FILE
            LAST_FILE="$(timeout 5 find "$BACKUP_DIR" -type f -name "*.zip" -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -1 | awk '{print $2}')"
            if [ -n "$LAST_FILE" ]; then
                DATA["icewarp.backup.last_file"]="$LAST_FILE"
                DATA["icewarp.backup.last_time"]="$(date -r "$LAST_FILE" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
            fi
        fi
    fi
}
