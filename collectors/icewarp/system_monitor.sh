#!/bin/bash

# Checklist: "Enable System Monitor: Mem:...4GB Disk:...100GB CPU:...% in 1 Min"
# Verified directly against System > Tools > System Monitor screenshot.
#
# BUGFIX: C_System_Tools_Monitor_CPUUsagePerc returns the value *100
# internally (live test showed UI=60% but raw tool.sh value=6000) - same
# storage convention IceWarp uses elsewhere (e.g. spam score properties).
# Now divided by 100 before reporting.

collector_run() {

    local FREE_MEM_KB
    local CPU_RAW

    collector_set "monitor.enabled" "$(iw_get "C_System_Tools_Monitor_Enable" "" "" "")"
    collector_set "monitor.alert_email" "$(iw_get "C_System_Tools_Monitor_ReportAddress" "" "" "")"

    FREE_MEM_KB="$(iw_get "C_System_Tools_Monitor_FreeMem" "" "" "")"
    collector_set "monitor.memory.alert_below_kb" "$FREE_MEM_KB"
    if [[ "$FREE_MEM_KB" =~ ^[0-9]+$ ]]; then
        collector_set "monitor.memory.alert_below_gb" "$(( FREE_MEM_KB / 1024 / 1024 ))"
    fi

    collector_set "monitor.disk.alert_below_mb" "$(iw_get "C_System_Tools_Monitor_DiskSize" "" "" "")"

    CPU_RAW="$(iw_get "C_System_Tools_Monitor_CPUUsagePerc" "" "" "")"
    if [[ "$CPU_RAW" =~ ^[0-9]+$ ]]; then
        collector_set "monitor.cpu.threshold_percent" "$(( CPU_RAW / 100 ))"
    else
        collector_set "monitor.cpu.threshold_percent" "$CPU_RAW"
    fi

    collector_set "monitor.cpu.threshold_minutes" "$(iw_get "C_System_Tools_Monitor_CPUUsagePeriod" "" "" "")"
    collector_set "monitor.web_threadpool.alert_seconds" "$(iw_get "C_System_Tools_Monitor_WebThreadPoolThreshold" "" "" "")"

}
