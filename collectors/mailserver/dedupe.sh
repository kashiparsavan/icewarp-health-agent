#!/bin/bash

# Checklist: "Dedupe Email Messages"
collector_run() {
    collector_set "smtp.dedupe" "$(iw_get "C_Mail_SMTP_Other_Dedupe" "" "" "")"
}
