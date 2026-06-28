#!/bin/bash

collector_run() {

    local VALUE=""

    if [ -f /opt/icewarp/license.xml ]
    then
        VALUE="installed"
    else
        VALUE="not_found"
    fi

    collector_set "icewarp.license.status" "$VALUE"

}
