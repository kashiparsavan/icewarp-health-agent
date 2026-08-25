#!/bin/bash

# Checklist: "Change Admin URL", "Change Admin Port"
#
# Both have direct API properties - no need for the curl-based heuristic
# that was considered, since tool.sh already exposes the configured values:
#   C_WebAdmin_URL                    - the WebAdmin path/URL
#   C_System_RemoteConsoleProtocol_Port - 0 means admin console uses the
#       normal webserver HTTP/HTTPS ports (i.e. NOT changed to a dedicated
#       port); any non-zero value means it WAS changed to a dedicated port.
#
# As you noted, many installs never change these from default, so N/A or
# "still default" will be the common result - this collector reports the
# raw values plus an explicit "changed_from_default" guess for the port
# (since 0 unambiguously means default; the URL has no such clean default
# marker, so it's reported as-is for the technician to judge).

collector_run() {

    local URL
    local PORT

    URL="$(iw_get "C_WebAdmin_URL" "" "" "")"
    PORT="$(iw_get "C_System_RemoteConsoleProtocol_Port" "" "" "")"

    collector_set "admin.url" "$URL"
    collector_set "admin.port_raw" "$PORT"

    # IceWarp's default WebAdmin path is "/admin/" - anything else means it
    # was changed. No dedicated tool.sh boolean for this exists, so this is
    # a path-comparison heuristic, not a direct property read.
    if [ -n "$URL" ]; then
        local URL_PATH
        URL_PATH="$(echo "$URL" | sed -E 's#^[a-zA-Z]+://[^/]+##' | tr '[:upper:]' '[:lower:]')"
        if [ "$URL_PATH" = "/admin/" ] || [ "$URL_PATH" = "/admin" ]; then
            collector_set "admin.url_changed_from_default" "false"
        else
            collector_set "admin.url_changed_from_default" "true"
        fi
    fi

    if [ "$PORT" = "0" ] || [ -z "$PORT" ]; then
        collector_set "admin.port_changed_from_default" "false"
    else
        collector_set "admin.port_changed_from_default" "true"
        collector_set "admin.dedicated_port" "$PORT"
    fi

}
