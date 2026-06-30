#!/bin/bash

# Checklist: "Max Message Size: ______ MB"
# Property verified in tool.help: C_Mail_SMTP_Delivery_MaxMsgSize (bytes)
# Enable flag: C_Mail_SMTP_Delivery_LimitMsgSize

collector_run() {

    local ENABLED
    local SIZE_BYTES

    ENABLED="$(iw_get "C_Mail_SMTP_Delivery_LimitMsgSize" "" "" "")"
    SIZE_BYTES="$(iw_get "C_Mail_SMTP_Delivery_MaxMsgSize" "" "" "")"

    collector_set "smtp.max_message_size.enabled" "$ENABLED"

    if [ -n "$SIZE_BYTES" ] && [[ "$SIZE_BYTES" =~ ^[0-9]+$ ]]; then
        collector_set "smtp.max_message_size.bytes" "$SIZE_BYTES"
        collector_set "smtp.max_message_size.mb" "$((SIZE_BYTES / 1024 / 1024))"
    else
        collector_set "smtp.max_message_size.bytes" ""
        collector_set "smtp.max_message_size.mb" ""
    fi

}
