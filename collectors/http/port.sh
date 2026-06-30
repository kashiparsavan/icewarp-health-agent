#!/bin/bash

# No tool.sh property was found for "the HTTP/WebAdmin port" in the API
# reference (tool.help / tool-search). This is normally stored in IceWarp's
# webserver.dat config file. As a last resort we fall back to asking the OS
# which port the IceWarp webserver process is actually listening on.
#
# IMPORTANT: verify CONFIG file name/path and the regex below against an
# actual server - "webserver.dat" is the commonly documented name but please
# confirm under ${IW_CONFIG} on your lab server.

collector_run() {

    local CONFIG_FILE="${IW_CONFIG}/webserver.dat"
    local VALUE

    VALUE="$(iw_get "" \
        "$CONFIG_FILE" \
        '(?i)^\s*Port\s*=\s*\K[0-9]+' \
        "ss -ltnp 2>/dev/null | grep -i webserver | awk '{print \$4}' | sed 's/.*://' | head -n1")"

    collector_set "http.port" "$VALUE"

}
