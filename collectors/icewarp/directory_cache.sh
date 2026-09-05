#!/bin/bash

###############################################################################
#
# IceWarp - Directory Cache
#
###############################################################################

collector_run() {

    local CONN_STRING
    local SCHEDULE

    CONN_STRING=$("$IW_TOOL" get system c_accounts_global_accounts_directorycacheconnectionstring 2>/dev/null | awk -F': ' '{print $2}')
    SCHEDULE=$("$IW_TOOL" get system c_accounts_global_accounts_directorycacheschedule 2>/dev/null | awk -F': ' '{print $2}')

    collector_set "directory_cache.connection_string" "$CONN_STRING"

    if [ -n "$SCHEDULE" ]; then
        collector_set "directory_cache.scheduled" "true"
        collector_set "directory_cache.schedule_raw" "$SCHEDULE"
        collector_set "directory_cache.next_run" "pending"
    else
        collector_set "directory_cache.scheduled" "false"
        collector_set "directory_cache.schedule_raw" "not scheduled"
        collector_set "directory_cache.next_run" "never"
    fi

}
