#!/bin/bash

###############################################################################
#
# IceWarp - DKIM
#
###############################################################################

collector_run() {

    local DKIM_ACTIVE

    DKIM_ACTIVE=$("$IW_TOOL" get system c_mail_security_dmarc_usedkim 2>/dev/null | awk -F': ' '{print $2}')

    if [ "$DKIM_ACTIVE" = "1" ]; then
        collector_set "icewarp.dkim.active_flag" "true"
    else
        collector_set "icewarp.dkim.active_flag" "false"
    fi

}
