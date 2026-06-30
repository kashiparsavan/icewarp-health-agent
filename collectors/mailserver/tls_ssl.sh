#!/bin/bash

# Checklist: "Use TLS/SSL (Secured Delivery)"
collector_run() {
    collector_set "smtp.use_tls_ssl" "$(iw_get "C_Mail_SMTP_Delivery_UseTLSSSL" "" "" "")"
}
