#!/bin/bash
# collectors/mailserver/delivery_reports.sh

collector_run() {
    # Delivery Reports (DSN)
    local DSN_DISABLE
    DSN_DISABLE="$(timeout 5 "$IW_TOOL" display system c_mail_smtp_other_disable_dsn 2>/dev/null | awk -F': ' '{print $2}')"
    if [ "$DSN_DISABLE" = "1" ]; then
        DATA["smtp.delivery_reports_enabled"]="0"
    else
        DATA["smtp.delivery_reports_enabled"]="1"
    fi

    # Bounceback Mode (0=enabled, 1=disabled - good)
    local BOUNCEBACK_MODE
    BOUNCEBACK_MODE="$(timeout 5 "$IW_TOOL" display system c_mail_smtp_other_bouncebackmode 2>/dev/null | awk -F': ' '{print $2}')"
    if [ -n "$BOUNCEBACK_MODE" ]; then
        DATA["c_mail_smtp_other_bouncebackmode"]="$BOUNCEBACK_MODE"
    fi
}
