#!/bin/bash

# Checklist: "Enable Database Backup" (distinct from the general system
# backup - collectors/icewarp/backup.sh).
# Source: C_System_Tools_Backup_DB_Accounts (confirmed in tool.help) - the
# accounts database's backup target DSN. Non-empty = configured/enabled.

collector_run() {
    local DSN
    DSN="$(iw_get "C_System_Tools_Backup_DB_Accounts" "" "" "")"
    collector_set "icewarp.database_backup.target_dsn" "$DSN"
    collector_set "icewarp.database_backup.enabled" "$([ -n "$DSN" ] && echo 1 || echo 0)"
}
