#!/bin/bash

# Checklist: "Enable SQL Failed Logs", "Enable Logging - Authentication and Maintenance"
collector_run() {
    collector_set "logging.sql_log_type" "$(iw_get "C_System_SQLLogType" "" "" "")"
    collector_set "logging.auth_log_level" "$(iw_get "C_Accounts_Global_Accounts_AuthLog" "" "" "")"
    collector_set "logging.maintenance_log_level" "$(iw_get "C_Accounts_Global_Accounts_MaintenanceLog" "" "" "")"
}
