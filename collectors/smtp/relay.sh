#!/bin/bash

collector_run() {

V="$(/opt/icewarp/tool.sh get system C_Mail_SMTP_Relay_Domains 2>/dev/null | awk -F': ' '{print $2}')"

collector_set "smtp.relay.domains" "$V"

}
