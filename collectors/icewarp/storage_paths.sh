#!/bin/bash

# FIXED: previously these paths came only from config/icewarp.conf (hardcoded
# defaults like /opt/icewarp/mail), which silently goes stale if an admin
# changes Storage > Directories in WebAdmin. Now reads from tool.sh first
# (the real, current configuration) and only falls back to the configured
# default if tool.sh is unavailable.
#
# Verified properties (Storage > Directories tab):
#   C_System_Storage_Dir_MailPath
#   C_System_Storage_Dir_TempPath
#   C_System_Storage_Dir_LogPath
#   C_System_Tools_AutoArchive_Path   (Archive path lives under AutoArchive,
#                                       not under Storage_Dir_* - verified,
#                                       there is no C_System_Storage_Dir_ArchivePath)

collector_run() {

    local MAIL_PATH TEMP_PATH LOG_PATH ARCHIVE_PATH

    MAIL_PATH="$(iw_get "C_System_Storage_Dir_MailPath" "" "" "")"
    TEMP_PATH="$(iw_get "C_System_Storage_Dir_TempPath" "" "" "")"
    LOG_PATH="$(iw_get "C_System_Storage_Dir_LogPath" "" "" "")"
    ARCHIVE_PATH="$(iw_get "C_System_Tools_AutoArchive_Path" "" "" "")"

    collector_set "icewarp.path.mail" "${MAIL_PATH:-$IW_MAIL}"
    collector_set "icewarp.path.temp" "${TEMP_PATH:-$IW_TEMP}"
    collector_set "icewarp.path.logs" "${LOG_PATH:-$IW_LOGS}"
    collector_set "icewarp.path.archive" "${ARCHIVE_PATH:-$IW_ARCHIVE}"

    # explicit flag so the report can show whether the value actually came
    # from the live server config or fell back to our configured default
    collector_set "icewarp.path.source" "$([ -n "$MAIL_PATH" ] && echo "tool_sh" || echo "config_default")"

}
