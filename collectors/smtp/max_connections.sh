#!/bin/bash

# Checklist: "Maximum Number of Simultaneous Threads: ______"
# Property verified in tool.help: C_System_Services_SMTP_ThreadCache
#
# NOTE: this collector used to be empty/ambiguous as "smtp.max_connections".
# Renamed to smtp.thread_cache because that is what this property actually
# represents; in/out connection limits are already covered separately by
# smtp/max_incoming_connections.sh and smtp/max_outgoing_connections.sh.

collector_run() {

    local VALUE
    VALUE="$(iw_get "C_System_Services_SMTP_ThreadCache" "" "" "")"

    collector_set "smtp.thread_cache" "$VALUE"

}
