#!/bin/bash

# Checklist: "Check TLS & StartTLS" - live protocol-level check.
#
# Root cause of the intermittent false "STARTTLS failed" (0.6.0 on 2026-10-31
# false, 0.7.0 on 2026-11-01 true, same server, same collector): the probe ran
# once, with the shared 5 s TOOL_TIMEOUT, against the public hostname, and kept
# no evidence. A slow connect (reverse-DNS/DNSBL lookups IceWarp does on every
# connection, hairpin NAT to its own public IP) killed openssl before the TLS
# summary and was reported as "STARTTLS unavailable". It also treated any
# "Verify return code" line as success.
#
# Now: dedicated timeout (STARTTLS_TIMEOUT, default 15 s), one retry, loopback
# fallback to tell "service broken" from "public path broken", strict success
# criterion (a TLS session with a real cipher) and recorded evidence.
#   smtp.starttls_live_test  true when STARTTLS works (hostname OR loopback)
#   smtp.starttls.via        hostname | loopback | none
#   smtp.starttls.protocol   TLSv1.3 ...        smtp.starttls.attempts  N
#   smtp.starttls.error      reason of the last failure (empty when via=hostname)
#   smtp.starttls.target     host actually probed first (no port, so the health
#                            message never repeats "via host:port")
#   smtp.starttls.trust      "not verified" - the probe never validates the chain

# _starttls_probe <connect host> <port> <sni> <timeout>
# sets _ST_OK (0/1), _ST_PROTO, _ST_ERR
_starttls_probe() {
    local CONNECT="$1" PORT="$2" SNI="$3" TMO="$4" OUT RC
    _ST_OK=0; _ST_PROTO=""; _ST_ERR=""

    OUT="$(printf 'QUIT\r\n' | timeout "$TMO" openssl s_client -starttls smtp \
            -connect "${CONNECT}:${PORT}" -servername "$SNI" 2>&1)"
    RC=$?

    if printf '%s' "$OUT" | grep -Eq '(^New, (TLSv|SSLv)|Protocol +: +(TLSv|SSLv))' \
       && ! printf '%s' "$OUT" | grep -q 'Cipher is (NONE)'; then
        _ST_OK=1
        _ST_PROTO="$(printf '%s' "$OUT" | grep -Eo 'TLSv[0-9.]+|SSLv[0-9.]+' | head -1)"
        return 0
    fi

    if printf '%s' "$OUT" | grep -qiE "didn't find starttls|did not find starttls"; then _ST_ERR="STARTTLS not offered by the server"
    elif [ "$RC" -eq 124 ]; then _ST_ERR="timeout after ${TMO}s"
    elif printf '%s' "$OUT" | grep -qiE 'connection refused|errno=111'; then _ST_ERR="connection refused"
    elif printf '%s' "$OUT" | grep -qiE 'handshake failure|alert|wrong version|unsupported protocol'; then _ST_ERR="TLS handshake failed"
    elif printf '%s' "$OUT" | grep -qiE 'name or service not known|temporary failure in name|could not resolve|getaddrinfo'; then _ST_ERR="hostname does not resolve"
    elif printf '%s' "$OUT" | grep -qiE 'no route|unreachable|network is'; then _ST_ERR="network unreachable"
    elif ! command -v openssl >/dev/null 2>&1; then _ST_ERR="openssl not installed"
    else _ST_ERR="no TLS session established"
    fi
    return 1
}

collector_run() {

    local HOST PORT TMO ATTEMPTS=0 VIA="none" PROTO="" ERR=""
    # Probe the real mail host: MAIL_HOSTNAME, else the primary domain's MX
    # target. The first mail domain is NOT used - it may not be the host that
    # actually answers SMTP.
    HOST="$(resolve_mail_mx)"
    [ -z "$HOST" ] && HOST="$(resolve_mail_hostname)"
    [ -z "$HOST" ] && HOST="localhost"
    PORT="${STARTTLS_PORT:-25}"
    TMO="${STARTTLS_TIMEOUT:-15}"
    [[ "$TMO" =~ ^[0-9]+$ ]] || TMO=15
    # Wall-clock budget for the whole probe (hostname + retry + loopback).
    # Each openssl run is already capped by TMO; this bounds the total.
    local STARTTLS_BUDGET="${STARTTLS_BUDGET:-45}"
    [[ "$STARTTLS_BUDGET" =~ ^[0-9]+$ ]] || STARTTLS_BUDGET=45
    local DEADLINE=$(( $(date +%s) + STARTTLS_BUDGET ))

    # 1) public hostname, one retry (transient slowness)
    ATTEMPTS=$((ATTEMPTS+1))
    if _starttls_probe "$HOST" "$PORT" "$HOST" "$TMO"; then
        VIA="hostname"; PROTO="$_ST_PROTO"
    else
        ERR="$_ST_ERR"
        # a server that does not offer STARTTLS is deterministic: do not retry
        if [ "$ERR" != "STARTTLS not offered by the server" ] && [ "$(date +%s)" -lt "$DEADLINE" ]; then
            ATTEMPTS=$((ATTEMPTS+1))
            if _starttls_probe "$HOST" "$PORT" "$HOST" "$TMO"; then
                VIA="hostname"; PROTO="$_ST_PROTO"; ERR=""
            else
                ERR="$_ST_ERR"
            fi
        fi
        if [ "$VIA" = "none" ] && [ "$ERR" != "STARTTLS not offered by the server" ] && [ "$(date +%s)" -lt "$DEADLINE" ]; then
            # 2) loopback: service itself vs the public path to it
            if [ "$HOST" != "localhost" ]; then
                ATTEMPTS=$((ATTEMPTS+1))
                if _starttls_probe "127.0.0.1" "$PORT" "$HOST" "$TMO"; then
                    VIA="loopback"; PROTO="$_ST_PROTO"
                    # "via host:port" appears once, in the health message; the
                    # collector error text says what works locally, not where.
                    ERR="${ERR}; works on 127.0.0.1"
                fi
            fi
        fi
    fi

    if [ "$VIA" = "none" ]; then
        collector_set "smtp.starttls_live_test" "false"
    else
        collector_set "smtp.starttls_live_test" "true"
    fi
    collector_set "smtp.starttls.via" "$VIA"
    collector_set "smtp.starttls.protocol" "$PROTO"
    collector_set "smtp.starttls.attempts" "$ATTEMPTS"
    collector_set "smtp.starttls.error" "$ERR"
    collector_set "smtp.starttls.target" "$HOST"
    # The probe never validates the certificate chain - it only negotiates a
    # session - so trust is explicitly "not verified" rather than implied.
    collector_set "smtp.starttls.trust" "not verified"

}
