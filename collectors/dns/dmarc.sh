#!/bin/bash

# Checklist: "Check DMARC"
collector_run() {

    if [ -z "${MAIL_HOSTNAME:-}" ]; then
        collector_set "dns.dmarc.checked" "false"
        collector_set "dns.dmarc.reason" "MAIL_HOSTNAME not set in config/icewarp.conf"
        return
    fi

    local DOMAIN="${MAIL_HOSTNAME#*.}"
    [ -z "$DOMAIN" ] && DOMAIN="$MAIL_HOSTNAME"

    local TXT
    TXT="$(timeout "$TOOL_TIMEOUT" dig +short TXT "_dmarc.${DOMAIN}" 2>/dev/null | grep -i 'v=DMARC1' | head -n1 | tr -d '"')"

    collector_set "dns.dmarc.checked" "true"
    collector_set "dns.dmarc.domain" "$DOMAIN"
    collector_set "dns.dmarc.found" "$([ -n "$TXT" ] && echo true || echo false)"
    collector_set "dns.dmarc.record" "$TXT"

}
