#!/bin/bash

# Determines which database backend this server actually uses, so the
# checklist's "MySQL Server" section can be marked N/A automatically when
# it doesn't apply (SQLite installs, or MySQL running locally on the same
# box - no separate server to check), and only triggers further
# investigation when a genuinely remote MySQL server is detected.
#
# Source: C_System_Storage_Accounts_ODBCConnString_Real - the resolved
# connection string for the main Accounts database (the database that
# matters for the SQLite -> local MySQL -> remote MySQL scaling decision,
# as opposed to the separate logging-only ODBC connection).

collector_run() {

    local CONN
    CONN="$(iw_get "C_System_Storage_Accounts_ODBCConnString_Real" "" "" "")"

    collector_set "database.connection_string_raw" "$CONN"

    if [ -z "$CONN" ]; then
        collector_set "database.type" "sqlite"
        collector_set "database.scope" "local"
        collector_set "database.mysql_server_section_applicable" "false"
        return
    fi

    if echo "$CONN" | grep -qi "sqlite"; then
        collector_set "database.type" "sqlite"
        collector_set "database.scope" "local"
        collector_set "database.mysql_server_section_applicable" "false"
        return
    fi

    # Real IceWarp SQLite connection strings look like
    # "config/accounts.db;;;;7;3" - a relative .db file path, not the
    # literal word "sqlite". Catch that pattern before falling through.
    if echo "$CONN" | grep -qiE '\.db(;|$)'; then
        collector_set "database.type" "sqlite"
        collector_set "database.scope" "local"
        collector_set "database.mysql_server_section_applicable" "false"
        return
    fi

    if echo "$CONN" | grep -qi "mysql\|mariadb"; then
        collector_set "database.type" "mysql"

        # try to extract host=... or Server=... from the DSN-style string
        local HOST
        HOST="$(echo "$CONN" | grep -oiP '(?:host|server)\s*=\s*\K[^;]+' | head -n1)"
        collector_set "database.host" "$HOST"

        if [ -z "$HOST" ] || [ "$HOST" = "127.0.0.1" ] || [ "$HOST" = "localhost" ]; then
            collector_set "database.scope" "local"
            collector_set "database.mysql_server_section_applicable" "false"
        else
            collector_set "database.scope" "remote"
            collector_set "database.mysql_server_section_applicable" "true"
        fi
        return
    fi

    # unrecognized connection string format
    collector_set "database.type" "unknown"
    collector_set "database.scope" "unknown"
    collector_set "database.mysql_server_section_applicable" "unknown"

}
