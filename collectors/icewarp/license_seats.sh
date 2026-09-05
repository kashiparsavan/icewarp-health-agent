#!/bin/bash

###############################################################################
#
# IceWarp - License Seats
#
###############################################################################

collector_run() {

    # در نسخه فعلی tool.sh متغیر مستقیمی برای used seats وجود ندارد
    collector_set "icewarp.license.used_seats_note" "not available via tool.sh - use API or database query"
    collector_set "icewarp.license.seats_info_available" "false"

}
