#!/bin/bash

collector_run() {

    local VERSION=""

    if [ -x /opt/icewarp/tool.sh ]
    then
        VERSION=$(/opt/icewarp/tool.sh display system c_version 2>/dev/null | awk -F': ' '{print $2}')
    fi

    collector_set "icewarp.version" "$VERSION"

}
