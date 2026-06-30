#!/bin/bash

# Property verified in tool.help: C_Mail_SMTP_General_RelayMailServer

collector_run() {

    local VALUE
    VALUE="$(iw_get "C_Mail_SMTP_General_RelayMailServer" "" "" "")"

    collector_set "smtp.relay.server" "$VALUE"

}
