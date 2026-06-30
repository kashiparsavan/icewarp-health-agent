#!/bin/bash

# Checklist: "Enable System Watchdog"
collector_run() {
    collector_set "watchdog.smtp" "$(iw_get "C_System_Tools_WatchDog_SMTP" "" "" "")"
    collector_set "watchdog.pop3" "$(iw_get "C_System_Tools_WatchDog_POP3" "" "" "")"
    collector_set "watchdog.check_protocols" "$(iw_get "C_System_Tools_Watchdog_Check_Protocols" "" "" "")"
}
