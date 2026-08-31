#!/bin/bash
# collectors/icewarp/protocol_advanced.sh
# Check IMAP and POP3 service status separately

collector_run() {
    # IMAP status
    local IMAP_ACTIVE="${DATA[service.imap.active]:-0}"
    DATA["service.imap.active"]="$IMAP_ACTIVE"

    # POP3 status
    local POP3_ACTIVE="${DATA[service.pop3.active]:-0}"
    DATA["service.pop3.active"]="$POP3_ACTIVE"
}
