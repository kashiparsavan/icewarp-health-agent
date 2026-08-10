#!/bin/bash

# Checklist: "Delivery Reports"
# Source: C_Mail_SMTP_Other_Disable_DSN (confirmed in tool.help). Note the
# inversion: the tool.sh property is "Disable DSN", so
# smtp.delivery_reports_enabled = NOT(Disable_DSN).

collector_run() {
    local DISABLED
    DISABLED="$(iw_get "C_Mail_SMTP_Other_Disable_DSN" "" "" "")"
    case "$DISABLED" in
        1|true|TRUE|True) collector_set "smtp.delivery_reports_enabled" "0" ;;
        0|false|FALSE|False) collector_set "smtp.delivery_reports_enabled" "1" ;;
        *) collector_set "smtp.delivery_reports_enabled" "" ;;
    esac
}
