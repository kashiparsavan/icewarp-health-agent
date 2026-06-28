#!/bin/bash

###############################################################################
#
# IceWarp Environment Collector
#
###############################################################################

collector_run() {

    collector_set "icewarp.home" "$ICEWARP_HOME"

    if [ -d "$ICEWARP_HOME" ]
    then
        collector_set "icewarp.installed" "true"
    else
        collector_set "icewarp.installed" "false"
        return
    fi

    TOOL="$ICEWARP_HOME/tool.sh"

    if [ -x "$TOOL" ]
    then
        collector_set "icewarp.tool" "$TOOL"
        collector_set "icewarp.tool.exists" "true"
    else
        collector_set "icewarp.tool.exists" "false"
    fi

    CONFIG="$ICEWARP_HOME/config"

    if [ -d "$CONFIG" ]
    then
        collector_set "icewarp.config" "$CONFIG"
    fi

    collector_set "icewarp.mail.default" "$ICEWARP_HOME/mail"
    collector_set "icewarp.logs.default" "$ICEWARP_HOME/logs"
    collector_set "icewarp.temp.default" "$ICEWARP_HOME/temp"
    collector_set "icewarp.archive.default" "$ICEWARP_HOME/archive"
    collector_set "icewarp.backup.default" "$ICEWARP_HOME/backup"

}
