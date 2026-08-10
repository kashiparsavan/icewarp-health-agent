#!/bin/bash

# Checklist: "Repository Access" (APP OS)
# Checks whether the configured package repos are actually reachable -
# using the package manager's own repo list/sync check rather than pinging
# an arbitrary external host, so it reflects exactly what "can this server
# actually install updates" means.

collector_run() {
    local REACHABLE=""

    if command -v dnf >/dev/null 2>&1; then
        if timeout "$TOOL_TIMEOUT" dnf repolist --refresh >/dev/null 2>&1; then
            REACHABLE="1"
        else
            REACHABLE="0"
        fi
    elif command -v yum >/dev/null 2>&1; then
        if timeout "$TOOL_TIMEOUT" yum makecache >/dev/null 2>&1; then
            REACHABLE="1"
        else
            REACHABLE="0"
        fi
    elif command -v apt-get >/dev/null 2>&1; then
        if timeout "$TOOL_TIMEOUT" apt-get update >/dev/null 2>&1; then
            REACHABLE="1"
        else
            REACHABLE="0"
        fi
    fi

    collector_set "os.repository_access" "$REACHABLE"
}
