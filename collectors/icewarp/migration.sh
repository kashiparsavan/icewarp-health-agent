#!/bin/bash

# Checklist: Migration safety - added after a real incident where an
# active migration was left running by mistake and took the whole service
# down. None of these should indicate an active/started/errored migration
# under normal healthy conditions - migration should be off.
#
# Sources (all confirmed in tool.help):
#   C_System_Tools_Migration_Active     Bool  "Enable Migration"
#   C_System_Tools_Migration_Server     String "Migration source host"
#   C_System_Tools_Migration_Stat_Start Int   "Unix time of start [R]" - NOT
#                                              a bool, a timestamp; 0/empty
#                                              means no migration has run
#   C_System_Tools_Migration_Stat_Errors Int  "Number of migration errors [R]"

collector_run() {

    collector_set "icewarp.migration.active" "$(iw_get "C_System_Tools_Migration_Active" "" "" "")"
    collector_set "icewarp.migration.server" "$(iw_get "C_System_Tools_Migration_Server" "" "" "")"

    local START_TS ERRORS
    START_TS="$(iw_get "C_System_Tools_Migration_Stat_Start" "" "" "")"
    ERRORS="$(iw_get "C_System_Tools_Migration_Stat_Errors" "" "" "")"

    collector_set "icewarp.migration.stat_start_raw" "$START_TS"
    if [[ "$START_TS" =~ ^[0-9]+$ ]] && [ "$START_TS" -gt 0 ]; then
        collector_set "icewarp.migration.stat_started" "true"
        collector_set "icewarp.migration.stat_start_human" "$(date -d "@${START_TS}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
    else
        collector_set "icewarp.migration.stat_started" "false"
    fi

    collector_set "icewarp.migration.stat_errors" "$ERRORS"
    if [[ "$ERRORS" =~ ^[0-9]+$ ]] && [ "$ERRORS" -gt 0 ]; then
        collector_set "icewarp.migration.has_errors" "true"
    else
        collector_set "icewarp.migration.has_errors" "false"
    fi

}
