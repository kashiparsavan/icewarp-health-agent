#!/bin/bash

# Checklist: "MySQL Server" section (IP, version, OS stats, repo access,
# time sync). Runs after database_type.sh (alphabetically later in the same
# folder, so DATA[database.type]/[database.scope] are already populated).
#
# - SQLite install: whole section marked not applicable (unchanged from
#   before - lib/pdf.sh already auto-renders this as N/A).
# - MySQL running LOCALLY (same box as IceWarp): we genuinely can check
#   this - service status, version, listening port - no credentials needed
#   for any of that. OS-level stats (disk/CPU/RAM/last update) are the
#   SAME machine IceWarp itself runs on, already collected by the os/*
#   collectors - this just cross-references them rather than duplicating.
# - MySQL on a SEPARATE remote box: this agent has no access to that
#   machine. We report what we legitimately know (the host, and whether we
#   can open a TCP connection to it) and mark the rest as needing either a
#   second agent run on that box or SSH access - not fabricated.

collector_run() {

    local DB_TYPE="${DATA[database.type]:-}"

    if [ "$DB_TYPE" != "mysql" ]; then
        collector_set "mysql.applicable" "false"
        return
    fi

    collector_set "mysql.applicable" "true"
    local SCOPE="${DATA[database.scope]:-unknown}"
    local HOST="${DATA[database.host]:-}"
    collector_set "mysql.scope" "$SCOPE"
    collector_set "mysql.host" "$HOST"

    if [ "$SCOPE" = "local" ]; then
        # Service status
        local SVC_ACTIVE=""
        if command -v systemctl >/dev/null 2>&1; then
            if systemctl is-active --quiet mysqld 2>/dev/null; then
                SVC_ACTIVE="1"; collector_set "mysql.service_name" "mysqld"
            elif systemctl is-active --quiet mariadb 2>/dev/null; then
                SVC_ACTIVE="1"; collector_set "mysql.service_name" "mariadb"
            else
                SVC_ACTIVE="0"
            fi
        fi
        collector_set "mysql.service_active" "$SVC_ACTIVE"

        # Version - no credentials needed, client/server binaries print
        # this without connecting
        local VERSION=""
        if command -v mysqld >/dev/null 2>&1; then
            VERSION="$(timeout "$TOOL_TIMEOUT" mysqld --version 2>/dev/null)"
        elif command -v mysql >/dev/null 2>&1; then
            VERSION="$(timeout "$TOOL_TIMEOUT" mysql --version 2>/dev/null)"
        fi
        collector_set "mysql.version_raw" "$VERSION"

        # Listening port (default 3306)
        local LISTENING="0"
        if command -v ss >/dev/null 2>&1; then
            timeout "$TOOL_TIMEOUT" ss -tln 2>/dev/null | grep -q ":3306" && LISTENING="1"
        fi
        collector_set "mysql.port_3306_listening" "$LISTENING"

        # Same machine as IceWarp - cross-reference, don't re-collect
        collector_set "mysql.os_version" "${DATA[general.os.pretty]:-}"
        collector_set "mysql.os_note" "same host as IceWarp - see general.os.* / os.* / storage.* for OS/disk/CPU/RAM detail"

    elif [ "$SCOPE" = "remote" ]; then
        collector_set "mysql.reachable" "$([ -n "$HOST" ] && timeout 3 bash -c "echo > /dev/tcp/${HOST}/3306" 2>/dev/null && echo 1 || echo 0)"
        collector_set "mysql.os_note" "remote MySQL server - OS/disk/CPU/RAM/repo/time-sync require running this agent on ${HOST:-that host} directly, or SSH access this agent doesn't have"

    else
        collector_set "mysql.os_note" "database scope could not be determined (see database.* keys)"
    fi

}
