#!/bin/bash

# Extends watchdog.sh (SMTP/POP3/check_protocols only) with the remaining
# services shown in System > Tools > Service Watchdog, confirmed against
# the real API Console property list (screenshot-verified, not guessed):
#   system.tools.watchdog.im / .gw / .control / .int / .check.iplist
#   system.tools.remoteserver.* (a genuinely separate module - "Remote
#   Server Watchdog" monitors reachability of OTHER servers, distinct from
#   the local-service watchdogs above)
#
# NOTE: "watchdog.web_rcp" existed in earlier versions of this collector
# but was never a real tool.sh property - it was a guess made before
# tool.help access was available, and has been removed. The real full set
# of watchdog properties is exactly what's collected below - confirmed
# against the API Console, nothing else exists under this section.

collector_run() {

    collector_set "watchdog.im" "$(iw_get "C_System_Tools_WatchDog_IM" "" "" "")"
    collector_set "watchdog.gw" "$(iw_get "C_System_Tools_Watchdog_GW" "" "" "")"
    collector_set "watchdog.control" "$(iw_get "C_System_Tools_Watchdog_Control" "" "" "")"
    collector_set "watchdog.interval_minutes" "$(iw_get "C_System_Tools_Watchdog_Int" "" "" "")"
    collector_set "watchdog.check_iplist" "$(iw_get "C_System_Tools_Watchdog_Check_IPList" "" "" "")"

    # Remote Server Watchdog - a separate module: monitors reachability of
    # OTHER servers (not this box's own local services). Confirmed via
    # API Console screenshot.
    collector_set "watchdog.remoteserver.enable" "$(iw_get "C_System_Tools_RemoteServer_Enable" "" "" "")"
    collector_set "watchdog.remoteserver.down_after_minutes" "$(iw_get "C_System_Tools_RemoteServer_MoreThan" "" "" "")"
    collector_set "watchdog.remoteserver.report_email" "$(iw_get "C_System_Tools_RemoteServer_Email" "" "" "")"
    collector_set "watchdog.remoteserver.notify_when_back" "$(iw_get "C_System_Tools_RemoteServer_NotifyAgain" "" "" "")"

}
