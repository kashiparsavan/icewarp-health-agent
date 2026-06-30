#!/bin/bash

# Checklist: "Enable System Monitor: Mem:...4GB Disk:...100GB CPU:...% in 1 Min"
# Verified directly against System > Tools > System Monitor screenshot.
#
# NOTE: C_System_Tools_Monitor_FreeMem is documented in kB but the WebAdmin
# UI shows/accepts GB (dropdown). Convert for readability; raw kB also kept.

collector_run() {

    local FREE_MEM_KB

    collector_set "monitor.enabled" "$(iw_get "C_System_Tools_Monitor_Enable" "" "" "")"
    collector_set "monitor.alert_email" "$(iw_get "C_System_Tools_Monitor_ReportAddress" "" "" "")"

    FREE_MEM_KB="$(iw_get "C_System_Tools_Monitor_FreeMem" "" "" "")"
    collector_set "monitor.memory.alert_below_kb" "$FREE_MEM_KB"
    if [[ "$FREE_MEM_KB" =~ ^[0-9]+$ ]]; then
        collector_set "monitor.memory.alert_below_gb" "$(( FREE_MEM_KB / 1024 / 1024 ))"
    fi

    collector_set "monitor.disk.alert_below_mb" "$(iw_get "C_System_Tools_Monitor_DiskSize" "" "" "")"
    collector_set "monitor.cpu.threshold_percent" "$(iw_get "C_System_Tools_Monitor_CPUUsagePerc" "" "" "")"
    collector_set "monitor.cpu.threshold_minutes" "$(iw_get "C_System_Tools_Monitor_CPUUsagePeriod" "" "" "")"
    collector_set "monitor.web_threadpool.alert_seconds" "$(iw_get "C_System_Tools_Monitor_WebThreadPoolThreshold" "" "" "")"

}
