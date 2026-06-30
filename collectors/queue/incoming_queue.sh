#!/bin/bash

collector_run() {

Q="$(/opt/icewarp/tool.sh get system C_Mail_SMTP_Delivery_IncomingQueueSize 2>/dev/null | awk -F': ' '{print $2}')"

collector_set "queue.smtp.incoming.size" "$Q"

}
