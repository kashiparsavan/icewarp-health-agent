#!/bin/bash

###############################################################################
#
# General - Operating System
#
###############################################################################

collector_run() {

    local NAME=""
    local VERSION=""

    if [ -f /etc/os-release ]
    then
        source /etc/os-release

        NAME="${NAME:-$ID}"
        VERSION="${VERSION_ID}"

        collector_set "general.os.name" "$NAME"
        collector_set "general.os.version" "$VERSION"
        collector_set "general.os.pretty" "$PRETTY_NAME"
    fi

}
