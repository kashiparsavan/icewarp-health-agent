#!/bin/bash

# Same situation as http/port.sh - no confirmed tool.sh property for the
# webserver's max simultaneous connections. Config-file fallback only;
# please verify key name on a real server (webserver.dat or similar).

collector_run() {

    local CONFIG_FILE="${IW_CONFIG}/webserver.dat"
    local VALUE

    VALUE="$(iw_get "" \
        "$CONFIG_FILE" \
        '(?i)^\s*MaxConnections\s*=\s*\K[0-9]+' \
        "")"

    collector_set "http.max_connections" "$VALUE"

}
