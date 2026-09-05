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
    
    # Check protocol settings
    DATA["service.imap.active"]="${DATA[service.imap.active]:-0}"
    DATA["service.pop3.active"]="${DATA[service.pop3.active]:-0}"
}
