#!/bin/bash

# Checklist: "Check DMARC"
# Real DNS TXT lookup, plus extracts the actual policy (p=none/quarantine/
# reject) since "a DMARC record exists" and "DMARC is actually enforcing
# anything" are very different things - p=none means monitoring only.

collector_run() {

    local DOMAIN
    DOMAIN="$(resolve_mail_hostname)"

    if [ -z "$DOMAIN" ]; then
        collector_set "dns.dmarc.checked" "false"
        collector_set "dns.dmarc.reason" "no domain found via tool.sh and MAIL_HOSTNAME not set"
        return
    fi

    local TXT_LINE TXT
    TXT_LINE="$(dig_resilient TXT "_dmarc.${DOMAIN}" | grep -i 'v=DMARC1' | head -n1)"
    TXT="$(dns_txt_join "$TXT_LINE")"

    collector_set "dns.dmarc.checked" "true"
    collector_set "dns.dmarc.domain" "$DOMAIN"
    collector_set "dns.dmarc.found" "$([ -n "$TXT" ] && echo true || echo false)"
    collector_set "dns.dmarc.record" "$TXT"

    if [ -n "$TXT" ]; then
        local POLICY
        POLICY="$(echo "$TXT" | grep -ioP 'p=\K[a-z]+' | head -n1)"
        collector_set "dns.dmarc.policy" "$POLICY"
        if [ "$POLICY" = "none" ]; then
            collector_set "dns.dmarc.policy_note" "p=none - monitoring only, not actually enforcing/blocking anything"
        fi
    fi

}
