#!/bin/bash

# Checklist: "Antispam Last Update"
#
# CORRECTED after live verification: the previous file-mtime-based approach
# was WRONG. It picked up Jun 20 10:50 (which is actually the IceWarp
# *installation* timestamp - confirmed by the api/ folder under /opt/icewarp
# sharing the exact same mtime) and misreported it as a real antispam rule
# update. The live WebAdmin screenshot (System > Anti-Spam > General) shows
# "Last update date: -/-/-", confirming antispam updates have in fact NEVER
# run on this server.
#
# Correct source (verified against tool.help): C_AS_Info_UpdateDate is the
# exact property backing that "Last update date" field. When updates have
# never run, IceWarp itself reports it as empty/"-/-/-", so an empty value
# here is a CORRECT result, not a collector failure - do not treat it as
# missing data and do not fall back to file mtimes, since we've proven those
# are misleading (they reflect install time, not update time).

collector_run() {

    local UPDATE_DATE
    local UPDATE_VERSION
    local UPDATE_SIZE

    UPDATE_DATE="$(iw_get "C_AS_Info_UpdateDate" "" "" "")"
    UPDATE_VERSION="$(iw_get "C_AS_Info_UpdateVersion" "" "" "")"
    UPDATE_SIZE="$(iw_get "C_AS_Info_UpdateSize" "" "" "")"

    collector_set "icewarp.antispam.last_update" "$UPDATE_DATE"
    collector_set "icewarp.antispam.last_update_source" "tool_sh"
    collector_set "icewarp.antispam.update_version" "$UPDATE_VERSION"
    collector_set "icewarp.antispam.last_update_size_bytes" "$UPDATE_SIZE"

    # Explicit, human-readable signal for the report/PDF stage - distinguishes
    # "never updated" (real or-not-applicable state) from "couldn't collect"
    if [ -z "$UPDATE_DATE" ] || [ "$UPDATE_DATE" = "-/-/-" ]; then
        collector_set "icewarp.antispam.ever_updated" "false"
    else
        collector_set "icewarp.antispam.ever_updated" "true"
    fi

}
