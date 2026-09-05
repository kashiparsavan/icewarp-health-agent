#!/bin/bash

# Checklist: "Time Sync" (APP OS) - genuine OS-level clock sync (chronyd/
# systemd-timesyncd/ntpd), distinct from IceWarp's own internal daytime
# clock sync feature (icewarp.daytime_clock_sync.enabled, a separate
# setting already collected in protocol_advanced.sh).

collector_run() {
    local SYNCED=""

    if command -v timedatectl >/dev/null 2>&1; then
        local STATUS
        STATUS="$(timeout "$TOOL_TIMEOUT" timedatectl show -p NTPSynchronized --value 2>/dev/null)"
        case "$STATUS" in
            yes) SYNCED="1" ;;
            no) SYNCED="0" ;;
        esac
        collector_set "os.time_sync.method" "timedatectl"
    elif command -v chronyc >/dev/null 2>&1; then
        if timeout "$TOOL_TIMEOUT" chronyc tracking 2>/dev/null | grep -qi "Leap status.*Normal"; then
            SYNCED="1"
        else
            SYNCED="0"
        fi
        collector_set "os.time_sync.method" "chronyc"
    fi

    collector_set "os.time_sync.synced" "$SYNCED"
}
