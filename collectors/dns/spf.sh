#!/bin/bash

# Checklist: "Check SPF"
# Auto-resolves the domain via resolve_mail_hostname() (backed by
# `tool list domain`) instead of requiring manual MAIL_HOSTNAME config.
collector_run() {

    local DOMAIN
    DOMAIN="$(resolve_mail_hostname)"

    if [ -z "$DOMAIN" ]; then
        collector_set "dns.spf.checked" "false"
        collector_set "dns.spf.reason" "no domain found via tool.sh and MAIL_HOSTNAME not set"
        return
    fi

    local TXT
    TXT="$(timeout "$TOOL_TIMEOUT" dig +short TXT "$DOMAIN" 2>/dev/null | grep -i 'v=spf1' | head -n1 | tr -d '"')"

    collector_set "dns.spf.checked" "true"
    collector_set "dns.spf.domain" "$DOMAIN"
    collector_set "dns.spf.found" "$([ -n "$TXT" ] && echo true || echo false)"
    collector_set "dns.spf.record" "$TXT"

}
