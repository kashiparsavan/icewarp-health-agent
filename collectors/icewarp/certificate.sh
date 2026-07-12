#!/bin/bash

# Checklist: "SSL Expiration Date" / "Check for Certificates"
#
# REWRITTEN: previously only read a local file path (IW_SSL_CERT) and asked
# openssl to parse it - if that path was wrong (or the cert is served by a
# proxy, or IceWarp binds a different file than the one manually configured)
# this silently returned nothing. Now it ALSO does a live check: connects
# to the mail domain on port 443 with openssl s_client and reads whatever
# certificate is actually being served, which is what really matters for
# "is our SSL cert about to expire" - matches how a browser or mail client
# would see it. Local file check is kept as a secondary/fallback data point.

collector_run() {

    local DOMAIN
    DOMAIN="$(resolve_mail_hostname)"
    [ -z "$DOMAIN" ] && DOMAIN="localhost"

    # --- Live check (the one that actually matters) ---
    local LIVE_RAW LIVE_EXPIRES
    LIVE_RAW="$(echo | timeout "$TOOL_TIMEOUT" openssl s_client -connect "${DOMAIN}:443" -servername "$DOMAIN" 2>/dev/null \
        | openssl x509 -noout -enddate 2>/dev/null)"
    LIVE_EXPIRES="${LIVE_RAW#notAfter=}"

    collector_set "icewarp.ssl.live_check_host" "${DOMAIN}:443"

    if [ -n "$LIVE_EXPIRES" ]; then
        collector_set "icewarp.ssl.expiration" "$LIVE_EXPIRES"
        collector_set "icewarp.ssl.source" "live (openssl s_client ${DOMAIN}:443)"

        local EXP_EPOCH NOW_EPOCH
        EXP_EPOCH="$(date -d "$LIVE_EXPIRES" +%s 2>/dev/null)"
        NOW_EPOCH="$(date +%s)"
        if [ -n "$EXP_EPOCH" ]; then
            collector_set "icewarp.ssl.days_left" "$(( (EXP_EPOCH - NOW_EPOCH) / 86400 ))"
        fi
    else
        collector_set "icewarp.ssl.source" "live check failed (no TLS listener on ${DOMAIN}:443, or handshake failed)"
    fi

    # --- Local file, as a secondary reference point ---
    collector_set "icewarp.ssl.cert_path" "${IW_SSL_CERT:-}"
    if [ -n "${IW_SSL_CERT:-}" ] && [ -f "$IW_SSL_CERT" ]; then
        local FILE_EXPIRES
        FILE_EXPIRES="$(timeout "$TOOL_TIMEOUT" openssl x509 -in "$IW_SSL_CERT" -noout -enddate 2>/dev/null | cut -d= -f2)"
        collector_set "icewarp.ssl.file_expiration" "$FILE_EXPIRES"

        # if the live check failed entirely, fall back to the file so we
        # still report SOMETHING rather than nothing
        if [ -z "$LIVE_EXPIRES" ] && [ -n "$FILE_EXPIRES" ]; then
            collector_set "icewarp.ssl.expiration" "$FILE_EXPIRES"
            collector_set "icewarp.ssl.source" "local file only (live check failed): ${IW_SSL_CERT}"
        fi
    fi

}
