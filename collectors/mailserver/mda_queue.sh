#!/bin/bash

# Checklist: "Process Incoming Messages in MDA Queue", "Use MDA Queue for Internal Message Delivery"
collector_run() {
    collector_set "smtp.use_incoming_queue" "$(iw_get "C_Mail_SMTP_Delivery_UseIncomingQueue" "" "" "")"
    collector_set "smtp.incoming_queue_threads" "$(iw_get "C_Mail_SMTP_Delivery_IncomingQueueSize" "" "" "")"
    collector_set "smtp.mda_internal_delivery" "$(iw_get "C_Mail_SMTP_Delivery_MDAInternal" "" "" "")"
}
