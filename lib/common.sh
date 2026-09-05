#!/bin/bash

declare -Ag DATA
declare -Ag STATUS
declare -Ag STATUS_MSG

TOOL_TIMEOUT="${TOOL_TIMEOUT:-5}"
LOCK_FILE="${LOCK_FILE:-${PROJECT_ROOT}/.agent.lock}"

agent_init() {
    DATA=()
    STATUS=()
    STATUS_MSG=()
    DATA["agent.version"]="${AGENT_VERSION}"
    DATA["agent.hostname"]="$(hostname 2>/dev/null || echo unknown)"
    DATA["agent.time"]="$(date '+%F %T')"
    if [ -n "${COMPANY_NAME:-}" ]; then
        DATA["general.company"]="$COMPANY_NAME"
    fi
}

collector_set() {
    local KEY="$1"
    local VALUE="${2:-}"
    DATA["$KEY"]="$VALUE"
}

_RESOLVED_MAIL_HOSTNAME=""
resolve_mail_hostname() {
    if [ -n "${MAIL_HOSTNAME:-}" ]; then
        printf '%s' "$MAIL_HOSTNAME"
        return
    fi
    if [ -n "$_RESOLVED_MAIL_HOSTNAME" ]; then
        printf '%s' "$_RESOLVED_MAIL_HOSTNAME"
        return
    fi
    local DOMAIN
    DOMAIN="$(iw_list_domains | head -n1)"
    _RESOLVED_MAIL_HOSTNAME="$DOMAIN"
    printf '%s' "$DOMAIN"
}

_RESOLVED_PUBLIC_IP=""
resolve_public_ip() {
    if [ -n "${MAIL_PUBLIC_IP:-}" ]; then
        printf '%s' "$MAIL_PUBLIC_IP"
        return
    fi
    if [ -n "$_RESOLVED_PUBLIC_IP" ]; then
        printf '%s' "$_RESOLVED_PUBLIC_IP"
        return
    fi
    local IP=""
    for SVC in "https://ifconfig.me" "https://icanhazip.com" "https://api.ipify.org" "https://ip.sb"; do
        IP="$(timeout 5 curl -s -4 --max-time 5 "$SVC" 2>/dev/null | tr -d '[:space:]')"
        [[ "$IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] && break
        IP=""
    done
    if [ -z "$IP" ]; then
        IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
        [ -n "$IP" ] && IP="${IP}(unconfirmed-local)"
    fi
    _RESOLVED_PUBLIC_IP="$IP"
    printf '%s' "$IP"
}

dig_resilient() {
    local ARGS=("$@")
    local RESULT
    RESULT="$(timeout "$TOOL_TIMEOUT" dig +short "${ARGS[@]}" 2>/dev/null)"
    if [ -n "$RESULT" ]; then
        printf '%s' "$RESULT"
        return
    fi
    for RESOLVER in 1.1.1.1 8.8.8.8; do
        RESULT="$(timeout "$TOOL_TIMEOUT" dig +short "${ARGS[@]}" "@${RESOLVER}" 2>/dev/null)"
        if [ -n "$RESULT" ]; then
            printf '%s' "$RESULT"
            return
        fi
    done
    printf ''
}

dns_txt_join() {
    local LINE="$1"
    local CHUNKS
    CHUNKS="$(printf '%s' "$LINE" | grep -oP '"[^"]*"')"
    if [ -n "$CHUNKS" ]; then
        printf '%s' "$CHUNKS" | tr -d '"' | tr -d '\n'
    else
        printf '%s' "$LINE" | tr -d '"'
    fi
}

acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local OLD_PID
        OLD_PID="$(cat "$LOCK_FILE" 2>/dev/null)"
        if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
            echo "[ERROR] Another agent run is already in progress (pid $OLD_PID). Aborting." >&2
            exit 1
        fi
        echo "[WARN] Stale lock file found (pid $OLD_PID not running). Removing." >&2
        rm -f "$LOCK_FILE"
    fi
    echo "$$" > "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE"
}

iw_get() {
    local TOOL_KEY="$1"
    local CONFIG_FILE="$2"
    local CONFIG_REGEX="$3"
    local OS_CMD="$4"
    local VALUE=""

    if [ -z "$VALUE" ] && [ -n "$TOOL_KEY" ] && [ -n "${IW_TOOL:-}" ] && [ -x "$IW_TOOL" ]; then
        VALUE="$(iw_tool_get "$TOOL_KEY")"
    fi

    if [ -z "$VALUE" ] && [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ] && [ -n "$CONFIG_REGEX" ]; then
        VALUE="$(grep -oP "$CONFIG_REGEX" "$CONFIG_FILE" 2>/dev/null | head -n1)"
    fi

    if [ -z "$VALUE" ] && [ -n "$OS_CMD" ]; then
        VALUE="$(timeout "$TOOL_TIMEOUT" bash -c "$OS_CMD" 2>/dev/null)"
    fi

    printf '%s' "$VALUE"
}

iw_list_domains() {
    if [ -z "${IW_TOOL:-}" ] || [ ! -x "$IW_TOOL" ]; then
        return
    fi
    timeout "$TOOL_TIMEOUT" "$IW_TOOL" list domain 2>/dev/null \
        | tr -d '\r' \
        | grep -v '^##.*##$' \
        | grep -v '^\s*$'
}

iw_get_domain() {
    local DOMAIN="$1"
    local TOOL_KEY="$2"
    local CONFIG_FILE="$3"
    local CONFIG_REGEX="$4"
    local OS_CMD="$5"
    local VALUE=""

    if [ -z "$DOMAIN" ]; then
        printf ''
        return
    fi

    if [ -n "$TOOL_KEY" ] && [ -n "${IW_TOOL:-}" ] && [ -x "$IW_TOOL" ]; then
        local RAW
        RAW="$(timeout "$TOOL_TIMEOUT" "$IW_TOOL" display domain "$DOMAIN" "$TOOL_KEY" 2>/dev/null)"
        RAW="${RAW//$'\r'/}"
        VALUE="$(printf '%s\n' "$RAW" | grep "^${TOOL_KEY}:" | awk -F': ' '{print $2}' | head -n1)"
    fi

    if [ -z "$VALUE" ] && [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ] && [ -n "$CONFIG_REGEX" ]; then
        VALUE="$(grep -oP "$CONFIG_REGEX" "$CONFIG_FILE" 2>/dev/null | head -n1)"
    fi

    if [ -z "$VALUE" ] && [ -n "$OS_CMD" ]; then
        VALUE="$(timeout "$TOOL_TIMEOUT" bash -c "$OS_CMD" 2>/dev/null)"
    fi

    printf '%s' "$VALUE"
}

iw_tool_get() {
    local KEY="$1"
    local RAW
    RAW="$(timeout 5 "$IW_TOOL" display system "$KEY" 2>/dev/null)"
    if [ -z "$RAW" ]; then
        printf ''
        return
    fi
    RAW="${RAW//$'\r'/}"
    printf '%s' "$RAW" | awk -F': ' '{print $2}' | head -n1
}

iw_tool_get_multiline() {
    local KEY="$1"
    local RAW
    RAW="$(timeout "$TOOL_TIMEOUT" "$IW_TOOL" display system "$KEY" 2>/dev/null)"
    RAW="${RAW//$'\r'/}"
    printf '%s' "$RAW" | sed '1s/^[^:]*:[[:space:]]*//'
}

run_collector() {
    local COLLECTOR_PATH="$1"
    local NAME="${COLLECTOR_PATH#$COLLECTOR_DIR/}"
    NAME="${NAME%.sh}"
    local ERR_FILE="/tmp/.collector_err.$$"

    source "$COLLECTOR_PATH"

    if ! declare -F collector_run >/dev/null; then
        unset -f collector_run 2>/dev/null
        return
    fi

    if collector_run 2>"$ERR_FILE"; then
        STATUS["$NAME"]="ok"
    else
        STATUS["$NAME"]="error"
        STATUS_MSG["$NAME"]="$(tail -n1 "$ERR_FILE" 2>/dev/null)"
    fi

    rm -f "$ERR_FILE"
    unset -f collector_run 2>/dev/null
}

list_collectors() {
    find "$COLLECTOR_DIR" -type f -name "*.sh" | \
        sed "s#${COLLECTOR_DIR}/##" | \
        sed 's#\.sh$##' | \
        sort
}

print_report() {
    echo
    echo "========================================"
    echo "IceWarp Health Check Report"
    echo "========================================"
    echo

    for KEY in $(printf "%s\n" "${!DATA[@]}" | sort)
    do
        printf "%-40s : %s\n" "$KEY" "${DATA[$KEY]}"
    done

    echo
    echo "Total Keys : ${#DATA[@]}"

    local FAILED=0
    for NAME in "${!STATUS[@]}"; do
        [ "${STATUS[$NAME]}" != "ok" ] && FAILED=$((FAILED+1))
    done

    if [ "$FAILED" -gt 0 ]; then
        echo
        echo "Collector issues (${FAILED}):"
        for NAME in $(printf "%s\n" "${!STATUS[@]}" | sort); do
            [ "${STATUS[$NAME]}" = "ok" ] && continue
            printf "  [%s] %-30s %s\n" "${STATUS[$NAME]}" "$NAME" "${STATUS_MSG[$NAME]:-}"
        done
    fi

    echo
}
