#!/bin/bash

collector_run() {

V="$(/opt/icewarp/tool.sh get system C_Mail_SMTP_Other_NoRetryQueue 2>/dev/null | awk -F': ' '{print $2}')"

collector_set "queue.smtp.no_retry" "$V"

}
