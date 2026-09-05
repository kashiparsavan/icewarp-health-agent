#!/bin/bash

# Checklist: "RBL Valli Check" (RBL = Realtime Blackhole List)
#
# NOTE: this is NOT the same thing as security.dnsbl.use
# (C_Mail_Security_Protection_DNSBL, collected in dnsbl_rdns.sh) - that
# property is whether IceWarp checks INCOMING mail senders against DNSBLs.
# This checklist item means something different: is OUR OWN server's
# outbound IP currently listed on a blacklist, which directly affects mail
# deliverability. That has to be checked by querying real RBL zones with
# our own IP, not by reading a config flag.

collector_run() {

    local IP
    IP="$(resolve_public_ip)"
    IP="${IP%%(*}"

    if [ -z "$IP" ]; then
        collector_set "security.rbl_self_check.checked" "false"
        collector_set "security.rbl_self_check.reason" "could not resolve a public IP to check"
        return
    fi

    collector_set "security.rbl_self_check.ip" "$IP"

    local REVERSED
    REVERSED="$(echo "$IP" | awk -F. '{print $4"."$3"."$2"."$1}')"

    local ZONES=(
        "zen.spamhaus.org"
        "bl.spamcop.net"
        "dnsbl.sorbs.net"
        "b.barracudacentral.org"
    )

    local ZONE LISTED_ON=() RESULT
    for ZONE in "${ZONES[@]}"; do
        RESULT="$(timeout "$TOOL_TIMEOUT" dig +short "${REVERSED}.${ZONE}" 2>/dev/null)"
        local SAFE_ZONE="${ZONE//./_}"
        if [ -n "$RESULT" ]; then
            collector_set "security.rbl_self_check.zones.${SAFE_ZONE}" "LISTED"
            LISTED_ON+=("$ZONE")
        else
            collector_set "security.rbl_self_check.zones.${SAFE_ZONE}" "clean"
        fi
    done

    collector_set "security.rbl_self_check.checked" "true"

    if [ "${#LISTED_ON[@]}" -eq 0 ]; then
        collector_set "security.rbl_self_check.listed" "false"
        collector_set "security.rbl_self_check.listed_on" ""
    else
        collector_set "security.rbl_self_check.listed" "true"
        collector_set "security.rbl_self_check.listed_on" "$(IFS=,; echo "${LISTED_ON[*]}")"
    fi

}
