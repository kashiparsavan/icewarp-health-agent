#!/bin/bash

# Checklist: "Check SPF"
# Real DNS TXT lookup (not an IceWarp config check). Also verifies whether
# the server's actual public IP is covered by the SPF record - checking
# literal ip4:/ip6: mechanisms AND resolving +a/+mx mechanisms, since many
# real SPF records (including a live one seen in testing) authorize via
# "+a +mx" rather than listing the IP literally.

collector_run() {

    local DOMAIN
    DOMAIN="$(resolve_mail_hostname)"

    if [ -z "$DOMAIN" ]; then
        collector_set "dns.spf.checked" "false"
        collector_set "dns.spf.reason" "no domain found via tool.sh and MAIL_HOSTNAME not set"
        return
    fi

    local TXT_LINE TXT
    TXT_LINE="$(dig_resilient TXT "$DOMAIN" | grep -i 'v=spf1' | head -n1)"
    TXT="$(dns_txt_join "$TXT_LINE")"

    collector_set "dns.spf.checked" "true"
    collector_set "dns.spf.domain" "$DOMAIN"
    collector_set "dns.spf.found" "$([ -n "$TXT" ] && echo true || echo false)"
    collector_set "dns.spf.record" "$TXT"

    if [ -z "$TXT" ]; then
        collector_set "dns.spf.includes_server_ip" "false"
        return
    fi

    local PUBLIC_IP
    PUBLIC_IP="$(resolve_public_ip)"
    PUBLIC_IP="${PUBLIC_IP%%(*}"

    if [ -z "$PUBLIC_IP" ]; then
        collector_set "dns.spf.includes_server_ip_note" "could not resolve public IP to check"
        return
    fi

    collector_set "dns.spf.checked_ip" "$PUBLIC_IP"
    local COVERED="false"

    # literal ip4:/ip6: mechanism
    if echo "$TXT" | grep -qi "ip4:${PUBLIC_IP}\b\|ip6:${PUBLIC_IP}\b"; then
        COVERED="true"
        collector_set "dns.spf.ip_coverage_via" "literal ip4/ip6 mechanism"
    fi

    # +a mechanism - domain's own A record must equal the public IP
    if [ "$COVERED" = "false" ] && echo "$TXT" | grep -qE '(\+|~|-|\?)?a([:/ ]|$)'; then
        local A_IP
        A_IP="$(dig_resilient A "$DOMAIN" | head -n1)"
        if [ -n "$A_IP" ] && [ "$A_IP" = "$PUBLIC_IP" ]; then
            COVERED="true"
            collector_set "dns.spf.ip_coverage_via" "a mechanism (${DOMAIN} A record matches)"
        fi
    fi

    # +mx mechanism - any of the domain's MX hosts' A records must equal the public IP
    if [ "$COVERED" = "false" ] && echo "$TXT" | grep -qE '(\+|~|-|\?)?mx([:/ ]|$)'; then
        local MX_HOST MX_IP
        for MX_HOST in $(dig_resilient MX "$DOMAIN" | awk '{print $2}' | sed 's/\.$//'); do
            [ -z "$MX_HOST" ] && continue
            MX_IP="$(dig_resilient A "$MX_HOST" | head -n1)"
            if [ "$MX_IP" = "$PUBLIC_IP" ]; then
                COVERED="true"
                collector_set "dns.spf.ip_coverage_via" "mx mechanism (${MX_HOST} A record matches)"
                break
            fi
        done
    fi

    collector_set "dns.spf.includes_server_ip" "$COVERED"

}
