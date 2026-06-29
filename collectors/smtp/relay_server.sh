#!/bin/bash

collector_run() {
    collector_set "smtp.relay.server" \
    "$(/opt/icewarp/tool.sh get system C_Mail_SMTP_General_RelayMailServer 2>/dev/null | awk -F': ' '{print $2}')"
}
