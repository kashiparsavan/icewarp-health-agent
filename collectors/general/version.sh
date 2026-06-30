#!/bin/bash

###############################################################################
#
# General - IceWarp Version
#
###############################################################################

collector_run() {

    local VERSION

    VERSION=$("$IW_TOOL" display system c_version 2>/dev/null | awk -F': ' '{print $2}')

    if [ -n "$VERSION" ]
    then
        collector_set "general.icewarp.version" "$VERSION"
    else
        collector_set "general.icewarp.version" "UNKNOWN"
    fi

}
