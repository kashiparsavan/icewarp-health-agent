#!/bin/bash

# Checklist: "Check DKIM"
#
# IMPORTANT / NEEDS VERIFICATION ON A REAL SERVER:
# D_DKIM_Active and D_DKIM_Selector are *domain-level* properties in
# tool.help, which normally need a domain argument on the tool.sh command
# line (something like: tool.sh display domain <domain> D_DKIM_Active).
# The exact CLI syntax for domain-scoped properties was not confirmed against
# a live server, so the tool.sh call below is a best-effort guess - please
# run it manually once and fix the syntax if it doesn't return a value.
#
# The DNS lookup part is reliable regardless of tool.sh syntax and is the
# best single source of truth for "is DKIM actually published correctly".

collector_run() {

    if [ -z "${MAIL_HOSTNAME:-}" ]; then
        collector_set "dns.dkim.checked" "false"
        collector_set "dns.dkim.reason" "MAIL_HOSTNAME not set in config/icewarp.conf"
        return
    fi

    local DOMAIN="${MAIL_HOSTNAME#*.}"
    [ -z "$DOMAIN" ] && DOMAIN="$MAIL_HOSTNAME"

    # best-effort, unverified domain-scoped tool.sh syntax
    local DKIM_ACTIVE
    if [ -x "$IW_TOOL" ]; then
        DKIM_ACTIVE="$(timeout "$TOOL_TIMEOUT" "$IW_TOOL" display domain "$DOMAIN" D_DKIM_Active 2>/dev/null | awk -F': ' '{print $2}')"
    fi
    collector_set "icewarp.dkim.active_flag" "$DKIM_ACTIVE"

    # DNS verification - tries the common "default" selector since the real
    # selector (D_DKIM_Selector) requires the same unverified domain syntax above
    local TXT
    TXT="$(timeout "$TOOL_TIMEOUT" dig +short TXT "default._domainkey.${DOMAIN}" 2>/dev/null | grep -i 'v=DKIM1' | head -n1 | tr -d '"')"

    collector_set "dns.dkim.checked" "true"
    collector_set "dns.dkim.domain" "$DOMAIN"
    collector_set "dns.dkim.selector_tried" "default"
    collector_set "dns.dkim.found" "$([ -n "$TXT" ] && echo true || echo false)"
    collector_set "dns.dkim.record" "$TXT"

}
