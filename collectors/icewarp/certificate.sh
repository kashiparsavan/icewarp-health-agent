#!/bin/bash

# Checklist: "SSL Expiration Date" / "Check for Certificates"
# No tool.sh property returns certificate expiration directly, so this reads
# the cert file path from icewarp.conf (IW_SSL_CERT) and asks openssl.
# Verify IW_SSL_CERT against the real certificate file on the server.

collector_run() {

    local EXPIRES
    local DAYS_LEFT

    if [ -f "$IW_SSL_CERT" ]; then
        EXPIRES="$(timeout "$TOOL_TIMEOUT" openssl x509 -in "$IW_SSL_CERT" -noout -enddate 2>/dev/null | cut -d= -f2)"
    fi

    collector_set "icewarp.ssl.cert_path" "$IW_SSL_CERT"
    collector_set "icewarp.ssl.expiration" "${EXPIRES:-}"

    if [ -n "${EXPIRES:-}" ]; then
        local EXP_EPOCH NOW_EPOCH
        EXP_EPOCH="$(date -d "$EXPIRES" +%s 2>/dev/null)"
        NOW_EPOCH="$(date +%s)"
        if [ -n "$EXP_EPOCH" ]; then
            DAYS_LEFT=$(( (EXP_EPOCH - NOW_EPOCH) / 86400 ))
            collector_set "icewarp.ssl.days_left" "$DAYS_LEFT"
        fi
    fi

}
