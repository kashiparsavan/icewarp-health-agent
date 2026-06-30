#!/bin/bash

# Checklist: "Check SPF"
collector_run() {

    if [ -z "${MAIL_HOSTNAME:-}" ]; then
        collector_set "dns.spf.checked" "false"
        collector_set "dns.spf.reason" "MAIL_HOSTNAME not set in config/icewarp.conf"
        return
    fi

    local DOMAIN="${MAIL_HOSTNAME#*.}"
    [ -z "$DOMAIN" ] && DOMAIN="$MAIL_HOSTNAME"

    local TXT
    TXT="$(timeout "$TOOL_TIMEOUT" dig +short TXT "$DOMAIN" 2>/dev/null | grep -i 'v=spf1' | head -n1 | tr -d '"')"

    collector_set "dns.spf.checked" "true"
    collector_set "dns.spf.domain" "$DOMAIN"
    collector_set "dns.spf.found" "$([ -n "$TXT" ] && echo true || echo false)"
    collector_set "dns.spf.record" "$TXT"

}
