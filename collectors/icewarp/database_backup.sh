#!/bin/bash
# collectors/icewarp/database_backup.sh
# FIXED: Use correct keys from tool.sh (with c_ prefix)

collector_run() {
    # Accounts database backup (c_system_tools_backup_db_accounts)
    local DSN_ACCOUNTS
    DSN_ACCOUNTS="$(iw_get "c_system_tools_backup_db_accounts" "" "" "")"
    collector_set "backup.db.accounts.target_dsn" "$DSN_ACCOUNTS"
    if [ -n "$DSN_ACCOUNTS" ]; then
        collector_set "backup.db.accounts.enabled" "1"
    else
        # Also check the boolean flag
        local ACCOUNTS_ENABLED
        ACCOUNTS_ENABLED="$(iw_get "c_system_tools_backup_db_accountsenabled" "" "" "")"
        collector_set "backup.db.accounts.enabled" "$([ "$ACCOUNTS_ENABLED" = "1" ] && echo 1 || echo 0)"
    fi

    # Anti-Spam database backup (c_system_tools_backup_db_as)
    local DSN_AS
    DSN_AS="$(iw_get "c_system_tools_backup_db_as" "" "" "")"
    collector_set "backup.db.as.target_dsn" "$DSN_AS"
    if [ -n "$DSN_AS" ]; then
        collector_set "backup.db.as.enabled" "1"
    else
        local AS_ENABLED
        AS_ENABLED="$(iw_get "c_system_tools_backup_db_asenabled" "" "" "")"
        collector_set "backup.db.as.enabled" "$([ "$AS_ENABLED" = "1" ] && echo 1 || echo 0)"
    fi

    # GroupWare database backup (c_system_tools_backup_db_gw)
    local DSN_GW
    DSN_GW="$(iw_get "c_system_tools_backup_db_gw" "" "" "")"
    collector_set "backup.db.gw.target_dsn" "$DSN_GW"
    if [ -n "$DSN_GW" ]; then
        collector_set "backup.db.gw.enabled" "1"
    else
        local GW_ENABLED
        GW_ENABLED="$(iw_get "c_system_tools_backup_db_gwenabled" "" "" "")"
        collector_set "backup.db.gw.enabled" "$([ "$GW_ENABLED" = "1" ] && echo 1 || echo 0)"
    fi

    # Directory Cache database backup (c_system_tools_backup_db_directorycache) - optional
    local DSN_CACHE
    DSN_CACHE="$(iw_get "c_system_tools_backup_db_directorycache" "" "" "")"
    collector_set "backup.db.cache.target_dsn" "$DSN_CACHE"
    if [ -n "$DSN_CACHE" ]; then
        collector_set "backup.db.cache.enabled" "1"
    else
        local CACHE_ENABLED
        CACHE_ENABLED="$(iw_get "c_system_tools_backup_db_directorycacheenabled" "" "" "")"
        collector_set "backup.db.cache.enabled" "$([ "$CACHE_ENABLED" = "1" ] && echo 1 || echo 0)"
    fi
}
