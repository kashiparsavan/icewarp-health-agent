#!/bin/bash

# Checklist (Security/Anti-Spam section), partial coverage:
#   bypass/whitelist behaviour around local IPs and domains
collector_run() {
    collector_set "antispam.bypass_local_ips" "$(iw_get "C_AS_BypassLocalIPs" "" "" "")"
    collector_set "antispam.bypass_local_domains" "$(iw_get "C_AS_BypassLocalDomains" "" "" "")"
    collector_set "antispam.max_threads" "$(iw_get "C_AS_SpamMaxThreads" "" "" "")"
    collector_set "antispam.mode" "$(iw_get "C_AS_General_AntispamMode" "" "" "")"
}
