#!/bin/bash

collector_run() {
    collector_set "smtp.max_outgoing_connections" \
    "$(/opt/icewarp/tool.sh get system C_System_Services_SMTP_MaxOutConn 2>/dev/null | awk -F': ' '{print $2}')"
}
