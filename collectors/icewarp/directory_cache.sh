#!/bin/bash

###############################################################################
#
# IceWarp - Directory Cache
#
# The schedule property is a multi-field "Schedule" value, so it is read whole
# (not just the second ": " field). Sources, in order: tool.sh display, tool.sh
# get, then the IceWarp config files. directory_cache.schedule_source records
# which one answered so a wrong guess is visible in the JSON.
#
###############################################################################

_dc_flatten() {
    # newline-separated tool output -> single line, empty lines dropped
    printf '%s' "$1" | tr -d '\r' | sed '/^[[:space:]]*$/d' | paste -sd'|' - | sed 's/|/ | /g'
}

_dc_tool() {
    # _dc_tool <display|get> <KEY>  -> whole value (multi-line safe)
    local MODE="$1" KEY="$2" RAW
    [ -n "${IW_TOOL:-}" ] && [ -x "$IW_TOOL" ] || return 0
    RAW="$(timeout "${TOOL_TIMEOUT:-5}" "$IW_TOOL" "$MODE" system "$KEY" 2>/dev/null)"
    printf '%s' "$RAW" | tr -d '\r' | sed '1s/^[^:]*:[[:space:]]*//'
}

collector_run() {

    local KEY_SCHED="C_Accounts_Global_Accounts_DirectoryCacheSchedule"
    local CONN_STRING SCHEDULE="" SOURCE="not_found" D F

    CONN_STRING="$(iw_get "C_Accounts_Global_Accounts_DirectoryCacheConnectionString" "" "" "")"
    collector_set "directory_cache.connection_string" "$(redact_dsn "$CONN_STRING")"

    SCHEDULE="$(_dc_flatten "$(_dc_tool display "$KEY_SCHED")")"
    [ -n "$SCHEDULE" ] && SOURCE="tool_sh_display"

    if [ -z "$SCHEDULE" ]; then
        SCHEDULE="$(_dc_flatten "$(_dc_tool get "$KEY_SCHED")")"
        [ -n "$SCHEDULE" ] && SOURCE="tool_sh_get"
    fi

    if [ -z "$SCHEDULE" ]; then
        for D in "${IW_CONFIG:-}" /opt/icewarp-data/config /opt/icewarp/config; do
            [ -n "$D" ] && [ -d "$D" ] || continue
            for F in "$D"/*.cfg "$D"/*.xml; do
                [ -f "$F" ] || continue
                SCHEDULE="$(grep -ihoP '<c_accounts_global_accounts_directorycacheschedule[^>]*>\K[^<]*' "$F" 2>/dev/null | head -n1)"
                if [ -n "$SCHEDULE" ]; then SOURCE="config:$(basename "$F")"; break 2; fi
            done
        done
    fi

    if [ -n "$SCHEDULE" ]; then
        collector_set "directory_cache.scheduled" "true"
        collector_set "directory_cache.schedule_raw" "$SCHEDULE"
        collector_set "directory_cache.next_run" "pending"
    else
        collector_set "directory_cache.scheduled" "false"
        collector_set "directory_cache.schedule_raw" "not scheduled"
        collector_set "directory_cache.next_run" "never"
    fi
    collector_set "directory_cache.schedule_source" "$SOURCE"

}
