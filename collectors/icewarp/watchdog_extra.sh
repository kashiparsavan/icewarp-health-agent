#!/bin/bash

# Extends the existing watchdog.sh (SMTP/POP3 only) with the remaining
# services shown in System > Tools > Service Watchdog, plus the global
# interval. ("Web/RCP" checkbox in the UI did not have a clearly matching
# tool.help property in the available reference subset - flagged below.)

collector_run() {

    collector_set "watchdog.im" "$(iw_get "C_System_Tools_WatchDog_IM" "" "" "")"
    collector_set "watchdog.gw" "$(iw_get "C_System_Tools_Watchdog_GW" "" "" "")"
    collector_set "watchdog.control" "$(iw_get "C_System_Tools_Watchdog_Control" "" "" "")"
    collector_set "watchdog.interval_minutes" "$(iw_get "C_System_Tools_Watchdog_Int" "" "" "")"

    # "Web / RCP" checkbox in UI - no confirmed property found yet
    collector_set "watchdog.web_rcp" ""
    collector_set "watchdog.web_rcp_status" "property_not_found"

}
