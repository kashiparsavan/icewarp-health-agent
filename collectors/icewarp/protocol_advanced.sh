#!/bin/bash
# collectors/icewarp/protocol_advanced.sh

collector_run() {
    # Check IMAP/POP3 service status (Strict Override: Disabled=PASS, Enabled=WARN)
    local IMAP_STATUS=""
    local POP3_STATUS=""
    if [ -n "${IW_TOOL:-}" ] && [ -x "$IW_TOOL" ]; then
        IMAP_STATUS="$(timeout 5 "$IW_TOOL" display system C_System_Services_IMAP_Enable 2>/dev/null | awk -F': ' '{print $2}' | tr -d ' ')"
        POP3_STATUS="$(timeout 5 "$IW_TOOL" display system C_System_Services_POP3_Enable 2>/dev/null | awk -F': ' '{print $2}' | tr -d ' ')"
    fi
    
    # IMAP/POP3: 0 (disabled) = PASS (control enforced), 1 (enabled) = WARN (control failed)
    if [ "$IMAP_STATUS" = "0" ] || [ "$IMAP_STATUS" = "false" ]; then
        DATA["service.imap.active"]="0"
    else
        DATA["service.imap.active"]="1"
    fi
    
    if [ "$POP3_STATUS" = "0" ] || [ "$POP3_STATUS" = "false" ]; then
        DATA["service.pop3.active"]="0"
    else
        DATA["service.pop3.active"]="1"
    fi
}
