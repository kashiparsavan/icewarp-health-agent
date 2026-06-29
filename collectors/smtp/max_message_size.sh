#!/bin/bash

collector_run() {

V="$(/opt/icewarp/tool.sh get system C_Mail_SMTP_General_MaxMessageSize 2>/dev/null | awk -F': ' '{print $2}')"

collector_set "smtp.max_message_size" "$V"

}
