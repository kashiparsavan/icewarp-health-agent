#!/bin/bash

collector_run() {

V="$(/opt/icewarp/tool.sh get system C_System_Log_MailQueue 2>/dev/null | awk -F': ' '{print $2}')"

collector_set "logging.mailqueue.level" "$V"

}
