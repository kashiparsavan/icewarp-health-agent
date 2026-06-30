#!/bin/bash

# Checklist: "Add rDNS Result to Received for All Messages", "Add Return-Path to All Messages"
collector_run() {
    collector_set "smtp.rdns_in_received" "$(iw_get "C_Mail_SMTP_Delivery_RDNSLookup" "" "" "")"
    collector_set "smtp.add_return_path" "$(iw_get "C_Mail_SMTP_Delivery_ReturnPath" "" "" "")"
}
