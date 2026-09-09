#!/bin/bash
# collectors/icewarp/security.sh
# Handles VRFY, DIGEST-MD5, and other security settings

collector_run() {
    if [ -n "${IW_TOOL:-}" ] && [ -x "$IW_TOOL" ]; then
        # ============================================================
        # VRFY (c_mail_security_protocols_denyvrfy)
        # ============================================================
        local DENY_VRFY
        DENY_VRFY="$(timeout 5 "$IW_TOOL" display system c_mail_security_protocols_denyvrfy 2>/dev/null | awk -F': ' '{print $2}' | tr -d ' ')"
        if [ "$DENY_VRFY" = "1" ] || [ "$DENY_VRFY" = "true" ]; then
            DATA["smtp.deny_vrfy"]="1"
        elif [ "$DENY_VRFY" = "0" ] || [ "$DENY_VRFY" = "false" ]; then
            DATA["smtp.deny_vrfy"]="0"
        else
            # If key not found, leave empty -> will show CRITICAL
            DATA["smtp.deny_vrfy"]=""
        fi

        # ============================================================
        # DIGEST-MD5 (c_auth_schemes)
        # ============================================================
        local AUTH_SCHEMES
        AUTH_SCHEMES="$(timeout 5 "$IW_TOOL" display system c_auth_schemes 2>/dev/null | awk -F': ' '{print $2}')"
        if [ -n "$AUTH_SCHEMES" ]; then
            # Check if DIGEST-MD5 is in the list
            if echo "$AUTH_SCHEMES" | grep -qi "DIGEST-MD5"; then
                DATA["security.digest_md5.enabled"]="true"
            else
                DATA["security.digest_md5.enabled"]="false"
            fi
        else
            # If key not found, leave empty -> will show INFO
            DATA["security.digest_md5.enabled"]=""
        fi
    fi
}
