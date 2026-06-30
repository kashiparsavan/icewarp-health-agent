#!/bin/bash

collector_run() {
    collector_set "smtp.parallel_ip_limit" \
    "$(/opt/icewarp/tool.sh get system C_Mail_SMTP_General_ParallelIPConnectionsLimit 2>/dev/null | awk -F': ' '{print $2}')"
}
