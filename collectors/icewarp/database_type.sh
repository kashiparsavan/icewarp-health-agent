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
    if echo "$CONN" | grep -qiE '^[^;]*\.db(;|$)'; then
        collector_set "database.type" "sqlite"
        collector_set "database.scope" "local"
        collector_set "database.mysql_server_section_applicable" "false"
        return
    fi

    if echo "$CONN" | grep -qi "mysql\|mariadb"; then
        collector_set "database.type" "mysql"
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

    # Positional MySQL DSN format, confirmed against a real MySQL install:
    # "accounts;icewarp;<encrypted-password>;127.0.0.1;3;2"
    #   field1=dbname field2=user field3=password field4=host field5+=type/port codes
    # No literal "mysql" text anywhere, and field1 has no .db extension - so
    # this only gets checked once both SQLite patterns above have failed.
    IFS=';' read -ra _DSN_PARTS <<< "$CONN"
    local F1="${_DSN_PARTS[0]:-}"
    local F4="${_DSN_PARTS[3]:-}"

    if [ -n "$F4" ] && [[ "$F4" =~ ^[a-zA-Z0-9.-]+$ ]] && [[ "$F1" != *.db ]]; then
        collector_set "database.type" "mysql"
        collector_set "database.host" "$F4"
        if [ "$F4" = "127.0.0.1" ] || [ "$F4" = "localhost" ] || [ "$F4" = "::1" ]; then
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
