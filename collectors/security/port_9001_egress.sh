#!/bin/bash

# Checklist: "Block outgoing port 9001"
# Checks the OS firewall directly for an explicit rule blocking outbound
# tcp/9001, rather than attempting a live outbound connection (unreliable -
# needs an external listener, and slow). Supports firewalld (Rocky/RHEL
# default) and falls back to raw iptables if firewalld isn't in use.

collector_run() {

    local METHOD="" BLOCKED=""

    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
        METHOD="firewalld"
        if timeout "$TOOL_TIMEOUT" firewall-cmd --list-all 2>/dev/null | grep -qE '9001'; then
            BLOCKED="true"
        else
            BLOCKED="false"
        fi
    elif command -v iptables >/dev/null 2>&1; then
        METHOD="iptables"
        if timeout "$TOOL_TIMEOUT" iptables -L OUTPUT -n 2>/dev/null | grep -qE '\b9001\b'; then
            BLOCKED="true"
        else
            BLOCKED="false"
        fi
    fi

    collector_set "security.port_9001_egress.method" "${METHOD:-none available}"

    if [ -z "$METHOD" ]; then
        collector_set "security.port_9001_egress.checked" "false"
        collector_set "security.port_9001_egress.reason" "neither firewalld nor iptables available/readable"
        return
    fi

    collector_set "security.port_9001_egress.checked" "true"
    collector_set "security.port_9001_egress.blocked" "$BLOCKED"

}
