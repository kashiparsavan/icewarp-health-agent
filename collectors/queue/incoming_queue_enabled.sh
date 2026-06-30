#!/bin/bash

collector_run() {

V="$(/opt/icewarp/tool.sh get system C_Mail_SMTP_Delivery_UseIncomingQueue 2>/dev/null | awk -F': ' '{print $2}')"

collector_set "queue.smtp.incoming.enabled" "$V"

}
