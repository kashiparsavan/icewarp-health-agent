#!/bin/bash

# Checklist: "Reject if SMTP AUTH Different from Sender" (appears in both
# SMTP/Message Processing and Security/Anti-Spam sections of the checklist)
collector_run() {
    collector_set "smtp.reject_auth_sender_mismatch" "$(iw_get "C_Mail_Security_Protection_RejectSMTPAuthSender" "" "" "")"
}
