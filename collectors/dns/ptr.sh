#!/bin/bash

# Checklist: "Check PTR"
# Live DNS check - requires MAIL_PUBLIC_IP set in config/icewarp.conf

collector_run() {

    if [ -z "${MAIL_PUBLIC_IP:-}" ]; then
        collector_set "dns.ptr.checked" "false"
        collector_set "dns.ptr.reason" "MAIL_PUBLIC_IP not set in config/icewarp.conf"
        return
    fi

    local PTR
    PTR="$(timeout "$TOOL_TIMEOUT" dig +short -x "$MAIL_PUBLIC_IP" 2>/dev/null | sed 's/\.$//')"

    collector_set "dns.ptr.checked" "true"
    collector_set "dns.ptr.ip" "$MAIL_PUBLIC_IP"
    collector_set "dns.ptr.result" "$PTR"
    collector_set "dns.ptr.matches_hostname" "$([ -n "$PTR" ] && [ "$PTR" = "${MAIL_HOSTNAME:-}" ] && echo true || echo false)"

}
