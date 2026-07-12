#!/bin/bash

# Checklist: "Check DMARC"
collector_run() {

    local DOMAIN
    DOMAIN="$(resolve_mail_hostname)"

    if [ -z "$DOMAIN" ]; then
        collector_set "dns.dmarc.checked" "false"
        collector_set "dns.dmarc.reason" "no domain found via tool.sh and MAIL_HOSTNAME not set"
        return
    fi

    local TXT
    TXT="$(timeout "$TOOL_TIMEOUT" dig +short TXT "_dmarc.${DOMAIN}" 2>/dev/null | grep -i 'v=DMARC1' | head -n1 | tr -d '"')"

    collector_set "dns.dmarc.checked" "true"
    collector_set "dns.dmarc.domain" "$DOMAIN"
    collector_set "dns.dmarc.found" "$([ -n "$TXT" ] && echo true || echo false)"
    collector_set "dns.dmarc.record" "$TXT"

}
