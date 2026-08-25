#!/bin/bash

# Checklist: "Check DKIM"
# Real DNS TXT lookup (not an IceWarp config check). DKIM selectors aren't
# discoverable via DNS alone - the mail server admin picks the selector
# name when generating the key. Tries IceWarp's own default ("default")
# plus several other common selector names as best-effort, since we can't
# know the real one without it being configured somewhere we can read.

collector_run() {

    local DOMAIN
    DOMAIN="$(resolve_mail_hostname)"

    if [ -z "$DOMAIN" ]; then
        collector_set "dns.dkim.checked" "false"
        collector_set "dns.dkim.reason" "no domain found via tool.sh and MAIL_HOSTNAME not set"
        return
    fi

    # cross-check: IceWarp's own config, if the domain-scoped property works
    local DKIM_ACTIVE
    if [ -x "$IW_TOOL" ]; then
        DKIM_ACTIVE="$(timeout "$TOOL_TIMEOUT" "$IW_TOOL" display domain "$DOMAIN" D_DKIM_Active 2>/dev/null | tr -d '\r' | awk -F': ' '{print $2}' | head -n1)"
    fi
    collector_set "icewarp.dkim.active_flag" "$DKIM_ACTIVE"

    collector_set "dns.dkim.checked" "true"
    collector_set "dns.dkim.domain" "$DOMAIN"

    local SELECTORS=("default" "dkim" "mail" "selector1" "selector2" "k1" "s1" "google")
    local SEL TXT FOUND_SELECTOR=""
    for SEL in "${SELECTORS[@]}"; do
        local TXT_LINE
        TXT_LINE="$(dig_resilient TXT "${SEL}._domainkey.${DOMAIN}" | grep -i 'v=DKIM1' | head -n1)"
        TXT="$(dns_txt_join "$TXT_LINE")"
        if [ -n "$TXT" ]; then
            FOUND_SELECTOR="$SEL"
            break
        fi
    done

    collector_set "dns.dkim.selectors_tried" "$(IFS=,; echo "${SELECTORS[*]}")"

    if [ -n "$FOUND_SELECTOR" ]; then
        collector_set "dns.dkim.found" "true"
        collector_set "dns.dkim.selector_found" "$FOUND_SELECTOR"
        collector_set "dns.dkim.record" "$TXT"
    else
        collector_set "dns.dkim.found" "false"
        collector_set "dns.dkim.selector_found" ""
        collector_set "dns.dkim.record" ""
        collector_set "dns.dkim.note" "none of the common selectors matched - if IceWarp uses a custom selector name, this will show a false negative. Check WebAdmin > Domain > DKIM for the real selector."
    fi

}
