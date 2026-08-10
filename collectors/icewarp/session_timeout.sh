#!/bin/bash

# Checklist: "Session Timeout (min)"
# Source: C_System_Adv_Protocols_SessionTimeOut (confirmed in tool.help,
# under Advanced Protocols settings).

collector_run() {
    collector_set "icewarp.session_timeout_minutes" "$(iw_get "C_System_Adv_Protocols_SessionTimeOut" "" "" "")"
}
