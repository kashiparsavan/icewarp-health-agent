#!/bin/bash
# collectors/icewarp/protocol_advanced.sh

collector_run() {
    # Get auth schemes from tool.sh with timeout
    local AUTH_SCHEMES=""
    if [ -n "${IW_TOOL:-}" ] && [ -x "$IW_TOOL" ]; then
        AUTH_SCHEMES="$(timeout 5 "$IW_TOOL" display system C_Mail_Security_AuthScheme 2>/dev/null | awk -F': ' '{print $2}')"
    fi
    
    if [ -n "$AUTH_SCHEMES" ]; then
        DATA["security.auth_schemes.raw"]="$AUTH_SCHEMES"
        # Check for DIGEST-MD5
        if [[ "$AUTH_SCHEMES" == *"DIGEST-MD5"* ]]; then
            DATA["security.digest_md5.enabled"]="true"
        else
            DATA["security.digest_md5.enabled"]="false"
        fi
    else
        DATA["security.auth_schemes.raw"]=""
        DATA["security.digest_md5.enabled"]="false"
    fi
    
    # Check IMAP/POP3 service status (Strict Override: Running=PASS, Disabled=WARN)
    local IMAP_STATUS=""
    local POP3_STATUS=""
    if [ -n "${IW_TOOL:-}" ] && [ -x "$IW_TOOL" ]; then
        IMAP_STATUS="$(timeout 5 "$IW_TOOL" display system C_System_Services_IMAP_Enable 2>/dev/null | awk -F': ' '{print $2}' | tr -d ' ')"
        POP3_STATUS="$(timeout 5 "$IW_TOOL" display system C_System_Services_POP3_Enable 2>/dev/null | awk -F': ' '{print $2}' | tr -d ' ')"
    fi
    
    if [ "$IMAP_STATUS" = "1" ] || [ "$IMAP_STATUS" = "true" ]; then
        DATA["service.imap.active"]="1"
    else
        DATA["service.imap.active"]="0"
    fi
    
    if [ "$POP3_STATUS" = "1" ] || [ "$POP3_STATUS" = "true" ]; then
        DATA["service.pop3.active"]="1"
    else
        DATA["service.pop3.active"]="0"
    fi
}
