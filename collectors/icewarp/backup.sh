#!/bin/bash

collector_run() {

    local LAST=""

    if [ -d /opt/icewarp/backup ]
    then
        LAST=$(find /opt/icewarp/backup -type f 2>/dev/null | sort | tail -1)
    fi

    collector_set "icewarp.backup.last_file" "$LAST"

}
