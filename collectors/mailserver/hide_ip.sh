#!/bin/bash

# Checklist: "Hide IP Address from Received for All Messages", "Hide Server Version"
collector_run() {
    collector_set "smtp.hide_ip" "$(iw_get "C_Mail_SMTP_Delivery_HideIP" "" "" "")"
    collector_set "smtp.hide_server_version" "$(iw_get "C_Mail_SMTP_Delivery_HideServerVersion" "" "" "")"
}
