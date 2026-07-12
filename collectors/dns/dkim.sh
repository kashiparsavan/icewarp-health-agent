#!/bin/bash

# Checklist: "Check DKIM"
# Auto-resolves the domain instead of requiring MAIL_HOSTNAME config. The
# tool.sh domain-scoped D_DKIM_Active/D_DKIM_Selector syntax is still
# unverified (see note below) - the DNS lookup half is reliable regardless.

collector_run() {

    local DOMAIN
    DOMAIN="$(resolve_mail_hostname)"

    if [ -z "$DOMAIN" ]; then
        collector_set "dns.dkim.checked" "false"
        collector_set "dns.dkim.reason" "no domain found via tool.sh and MAIL_HOSTNAME not set"
        return
    fi

    # best-effort, unverified domain-scoped tool.sh syntax
    local DKIM_ACTIVE
    if [ -x "$IW_TOOL" ]; then
        DKIM_ACTIVE="$(timeout "$TOOL_TIMEOUT" "$IW_TOOL" display domain "$DOMAIN" D_DKIM_Active 2>/dev/null | awk -F': ' '{print $2}')"
    fi
    collector_set "icewarp.dkim.active_flag" "$DKIM_ACTIVE"

    local TXT
    TXT="$(timeout "$TOOL_TIMEOUT" dig +short TXT "default._domainkey.${DOMAIN}" 2>/dev/null | grep -i 'v=DKIM1' | head -n1 | tr -d '"')"

    collector_set "dns.dkim.checked" "true"
    collector_set "dns.dkim.domain" "$DOMAIN"
    collector_set "dns.dkim.selector_tried" "default"
    collector_set "dns.dkim.found" "$([ -n "$TXT" ] && echo true || echo false)"
    collector_set "dns.dkim.record" "$TXT"

}
