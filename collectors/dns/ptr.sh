#!/bin/bash

# Checklist: "Check PTR"
# Auto-resolves the public IP via resolve_public_ip() instead of requiring
# manual MAIL_PUBLIC_IP config.
collector_run() {

    local IP HOSTNAME_NOW
    IP="$(resolve_public_ip)"
    IP="${IP%%(*}"   # strip the "(unconfirmed-local)" suffix if present, for the dig call itself

    if [ -z "$IP" ]; then
        collector_set "dns.ptr.checked" "false"
        collector_set "dns.ptr.reason" "could not resolve a public IP (no internet egress and MAIL_PUBLIC_IP not set)"
        return
    fi

    HOSTNAME_NOW="$(resolve_mail_hostname)"

    local PTR
    PTR="$(timeout "$TOOL_TIMEOUT" dig +short -x "$IP" 2>/dev/null | sed 's/\.$//')"

    collector_set "dns.ptr.checked" "true"
    collector_set "dns.ptr.ip" "$(resolve_public_ip)"
    collector_set "dns.ptr.result" "$PTR"
    collector_set "dns.ptr.exists" "$([ -n "$PTR" ] && echo true || echo false)"
    collector_set "dns.ptr.matches_hostname" "$([ -n "$PTR" ] && [ "$PTR" = "$HOSTNAME_NOW" ] && echo true || echo false)"

}
