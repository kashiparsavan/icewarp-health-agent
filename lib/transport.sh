#!/bin/bash

###############################################################################
#
# Transport
#
# POSTs the health JSON to $MONITOR_URL. The payload is health.json (v1, the
# flat 411-key namespace) - the v2 envelope is a separate artifact and is NOT
# what gets posted, so monitoring clients that parse the flat keys keep working.
#
# Hardening:
#   * MONITOR_URL and the payload file are validated before anything is sent.
#   * --connect-timeout / --max-time bound the network wait; --retry makes a
#     flaky link recoverable instead of failing the whole agent run.
#   * an optional auth header (MONITOR_AUTH_HEADER) is forwarded verbatim.
#   * the curl exit status is returned and logged by the caller.
#
###############################################################################

# _transport_usage -> prints the short usage note for a bad configuration.
_transport_usage() {
    echo "[ERROR] send_json: $1" >&2
    echo "[ERROR] send_json: set MONITOR_URL=<https://host/path> and SEND_DATA=1 to post health.json" >&2
}

send_json() {

    if [ "$SEND_DATA" != "1" ]; then
        echo "[INFO] SEND_DATA disabled"
        return 0
    fi

    if [ -z "${MONITOR_URL:-}" ]; then
        _transport_usage "MONITOR_URL is not set"
        return 2
    fi

    case "$MONITOR_URL" in
        http://*|https://*) : ;;
        *) _transport_usage "MONITOR_URL must be an http(s) URL (got: ${MONITOR_URL})"; return 2 ;;
    esac

    if [ ! -f "$OUTPUT_JSON" ]; then
        _transport_usage "payload not found: ${OUTPUT_JSON}"
        return 2
    fi

    if [ ! -s "$OUTPUT_JSON" ]; then
        _transport_usage "payload is empty: ${OUTPUT_JSON}"
        return 2
    fi

    # curl flags. Defaults keep the old behaviour (silent, fail on HTTP errors)
    # while adding the bounds the collector run needs.
    local CT="${MONITOR_CONNECT_TIMEOUT:-10}"
    local MT="${MONITOR_MAX_TIME:-30}"
    local RETRY="${MONITOR_RETRY:-2}"
    local RETRY_DELAY="${MONITOR_RETRY_DELAY:-5}"
    [[ "$CT" =~ ^[0-9]+$ ]] || CT=10
    [[ "$MT" =~ ^[0-9]+$ ]] || MT=30
    [[ "$RETRY" =~ ^[0-9]+$ ]] || RETRY=2
    [[ "$RETRY_DELAY" =~ ^[0-9]+$ ]] || RETRY_DELAY=5

    local -a CURL_ARGS=(
        --silent
        --show-error
        --fail
        --connect-timeout "$CT"
        --max-time "$MT"
        --retry "$RETRY"
        --retry-delay "$RETRY_DELAY"
        --retry-connrefused
        -H "Content-Type: application/json"
        --data @"$OUTPUT_JSON"
    )

    [ -n "${MONITOR_AUTH_HEADER:-}" ] && CURL_ARGS+=(-H "$MONITOR_AUTH_HEADER")

    echo "[INFO] send_json: POST ${MONITOR_URL} (${OUTPUT_JSON}, connect<=${CT}s max<=${MT}s retry=${RETRY})"

    curl "${CURL_ARGS[@]}" "$MONITOR_URL"
    local CURL_RC=$?

    if [ "$CURL_RC" -ne 0 ]; then
        echo "[ERROR] send_json: curl failed (exit ${CURL_RC}) posting to ${MONITOR_URL}" >&2
    else
        echo "[INFO] send_json: POST accepted by ${MONITOR_URL}"
    fi

    return "$CURL_RC"

}