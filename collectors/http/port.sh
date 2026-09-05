#!/bin/bash

###############################################################################
#
# HTTP - Port
#
###############################################################################

collector_run() {

    local PORT

    PORT=$("$IW_TOOL" get system c_system_services_control_sslport 2>/dev/null | awk -F': ' '{print $2}')

    if [ -n "$PORT" ]; then
        collector_set "http.port" "$PORT"
    else
        collector_set "http.port" "443"
    fi

    # http.max_connections در این نسخه قابل دریافت نیست
    collector_set "http.max_connections" "null"

}
