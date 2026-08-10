#!/bin/bash

# Checklist: "APP OS Last Update"
# Uses dnf/yum history (Rocky/RHEL) to find the most recent package
# transaction date - falls back to apt (Debian/Ubuntu) if present.

collector_run() {
    local LAST_DATE=""

    if command -v dnf >/dev/null 2>&1; then
        collector_set "os.package_manager" "dnf"
        LAST_DATE="$(timeout "$TOOL_TIMEOUT" dnf history 2>/dev/null | awk -F'|' 'NR==3{gsub(/^[ \t]+|[ \t]+$/,"",$3); print $3}')"
    elif command -v yum >/dev/null 2>&1; then
        collector_set "os.package_manager" "yum"
        LAST_DATE="$(timeout "$TOOL_TIMEOUT" yum history 2>/dev/null | awk -F'|' 'NR==3{gsub(/^[ \t]+|[ \t]+$/,"",$3); print $3}')"
    elif command -v apt >/dev/null 2>&1; then
        collector_set "os.package_manager" "apt"
        LAST_DATE="$(timeout "$TOOL_TIMEOUT" bash -c "ls -lt /var/log/apt/history.log* 2>/dev/null | head -n1 | awk '{print \$6, \$7, \$8}'")"
    else
        collector_set "os.package_manager" "unknown"
    fi

    collector_set "os.last_update_date" "$LAST_DATE"
}
