#!/bin/bash
# collectors/security/port_9001_egress.sh
# Check if outgoing port 9001 is blocked

collector_run() {
    local BLOCKED=false
    local METHOD=""

    # Check firewalld
    if command -v firewall-cmd &>/dev/null; then
        # If port 9001 is NOT in the list, it's blocked (good)
        if firewall-cmd --zone=public --list-ports 2>/dev/null | grep -q ":9001"; then
            BLOCKED=false
            METHOD="firewalld (port is open - BAD)"
        else
            BLOCKED=true
            METHOD="firewalld (port not in list - GOOD)"
        fi
    # Check iptables as fallback
    elif command -v iptables &>/dev/null; then
        if iptables -L -n 2>/dev/null | grep -q "dport 9001"; then
            BLOCKED=true
            METHOD="iptables (rule found - GOOD)"
        else
            BLOCKED=false
            METHOD="iptables (no rule found - BAD)"
        fi
    else
        BLOCKED=false
        METHOD="no firewall tool found"
    fi

    collector_set "security.port_9001_egress.blocked" "$BLOCKED"
    collector_set "security.port_9001_egress.checked" "true"
    collector_set "security.port_9001_egress.method" "$METHOD"
}
