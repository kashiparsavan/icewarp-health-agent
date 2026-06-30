#!/bin/bash

collector_run() {
    collector_set "smtp.max_incoming_connections" \
    "$(/opt/icewarp/tool.sh get system C_System_Services_SMTP_MaxInConn 2>/dev/null | awk -F': ' '{print $2}')"
}
