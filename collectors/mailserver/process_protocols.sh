#!/bin/bash

# Checklist: "Process SMTP", "Process POP3/IMAP", "Disable VRFY"
collector_run() {
    collector_set "service.smtp.active" "$(iw_get "C_Mail_SMTP_Active" "" "" "")"
    collector_set "service.imap.active" "$(iw_get "C_Mail_IMAP_Active" "" "" "")"
    collector_set "service.pop3.active" "$(iw_get "C_Mail_POP_Active" "" "" "")"
    collector_set "smtp.deny_vrfy" "$(iw_get "C_Mail_Security_Protocols_DenyVRFY" "" "" "")"
}
