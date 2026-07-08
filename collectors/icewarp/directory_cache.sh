#!/bin/bash

# Checklist: "Set Directory Cache Schedule to ______"
# User just wants: is it scheduled, and what's the next run time.
#
# Property: C_Accounts_Global_Accounts_DirectoryCacheSchedule (type "Schedule"
# in tool.help - a structured, non-trivial format, not a plain string/int).
# We don't yet know its exact encoding, so for now this collector reports
# the RAW value as-is. Once we see a real raw value from a live server, the
# parsing logic can be added to turn it into enabled/next_run fields
# properly (the WebAdmin "Next run" field is most likely computed
# client-side from this schedule data, not stored as a separate property).

collector_run() {

    local RAW
    RAW="$(iw_get "C_Accounts_Global_Accounts_DirectoryCacheSchedule" "" "" "")"

    collector_set "directory_cache.schedule_raw" "$RAW"
    collector_set "directory_cache.scheduled" "$([ -n "$RAW" ] && echo true || echo false)"
    collector_set "directory_cache.next_run" "unparsed_pending_format_confirmation"

}
