#!/bin/bash

###############################################################################
#
# Transport
#
###############################################################################

send_json() {

    if [ "$SEND_DATA" != "1" ]
    then

        echo "[INFO] SEND_DATA disabled"

        return

    fi

    curl \
        --silent \
        --show-error \
        --fail \
        -H "Content-Type: application/json" \
        --data @"$OUTPUT_JSON" \
        "$MONITOR_URL"

}
