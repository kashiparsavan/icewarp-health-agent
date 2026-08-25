#!/bin/bash

###############################################################################
#
# Common Library
#
###############################################################################

declare -Ag DATA
declare -Ag STATUS          # per-collector status: ok | error | timeout
declare -Ag STATUS_MSG      # optional error message per collector

TOOL_TIMEOUT="${TOOL_TIMEOUT:-5}"   # seconds, applies to tool.sh / OS command fallback
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

###############################################################################
# Auto-resolvers - so DNS/certificate collectors never require manually
# configured MAIL_HOSTNAME / MAIL_PUBLIC_IP. Config values still win if set
# (explicit override), otherwise these derive them live:
#   hostname -> first real domain from `tool list domain` (iw_list_domains)
#   public IP -> external echo services, falling back to the local primary
#                IP (clearly labeled as unconfirmed) if outbound internet
#                to those services isn't available
# Both are cached per-run (collectors run in the same shell, not subshells -
# see run_collector below) so the network/tool.sh cost is paid once even
# though several collectors need these.
###############################################################################

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
    local SVC
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

###############################################################################
# Resilient DNS lookup - if the OS default resolver (/etc/resolv.conf)
# returns nothing, retries against known-good public resolvers before
# giving up. Protects every DNS-based collector from a single misconfigured
# or flaky default resolver silently producing "not found" everywhere.
###############################################################################

dig_resilient() {
    local ARGS=("$@")
    local RESULT
    RESULT="$(timeout "$TOOL_TIMEOUT" dig +short "${ARGS[@]}" 2>/dev/null)"
    if [ -n "$RESULT" ]; then
        printf '%s' "$RESULT"
        return
    fi
    local RESOLVER
    for RESOLVER in 1.1.1.1 8.8.8.8; do
        RESULT="$(timeout "$TOOL_TIMEOUT" dig +short "${ARGS[@]}" "@${RESOLVER}" 2>/dev/null)"
        if [ -n "$RESULT" ]; then
            printf '%s' "$RESULT"
            return
        fi
    done
    printf ''
}

# Properly concatenates a DNS TXT record's quoted chunks with no inserted
# separator, per DNS TXT chunking rules - a TXT value longer than 255
# bytes gets split into multiple quoted character-strings by the DNS
# protocol itself, and they must be joined directly (not with a space) to
# reconstruct the real value. Naive `tr -d '"'` on dig's +short output
# leaves the space that sits between the closing and opening quotes,
# silently corrupting anything that spans a chunk boundary (e.g. a DKIM
# public key). Takes one line of `dig +short TXT` output.
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

###############################################################################
# Locking - prevents overlapping runs (e.g. triggered by cron)
###############################################################################

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

###############################################################################
# Generic value resolver implementing the priority chain:
#   tool.sh  ->  Config file  ->  OS command
#
# (API/HTTP and SQL layers are not wired in yet - see README/roadmap. They can
#  be added as two extra arguments once WebAdmin API / DB credentials exist.)
#
# Usage:
#   iw_get "<tool.sh property>" "<config file>" "<grep -oP regex>" "<os command>"
#
# Any argument can be passed as "" to skip that layer.
###############################################################################

iw_get() {

    local TOOL_KEY="$1"
    local CONFIG_FILE="$2"
    local CONFIG_REGEX="$3"
    local OS_CMD="$4"
    local VALUE=""

    # 1. tool.sh
    if [ -z "$VALUE" ] && [ -n "$TOOL_KEY" ] && [ -n "${IW_TOOL:-}" ] && [ -x "$IW_TOOL" ]; then
        VALUE="$(iw_tool_get "$TOOL_KEY")"
    fi

    # 2. Config file
    if [ -z "$VALUE" ] && [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ] && [ -n "$CONFIG_REGEX" ]; then
        VALUE="$(grep -oP "$CONFIG_REGEX" "$CONFIG_FILE" 2>/dev/null | head -n1)"
    fi

    # 3. OS command (last resort)
    if [ -z "$VALUE" ] && [ -n "$OS_CMD" ]; then
        VALUE="$(timeout "$TOOL_TIMEOUT" bash -c "$OS_CMD" 2>/dev/null)"
    fi

    printf '%s' "$VALUE"

}

# Auto-discovers the real (non-internal) domains hosted on this server, so
# domain-scoped collectors never need a manually-configured domain name -
# critical for running unmodified across hundreds of production servers.
#
# Verified live syntax: `tool list domain` prints one domain per line, plus
# an internal service domain ("##internalservicedomain.icewarp.com##") which
# every IceWarp install has and which is NOT a real customer domain - it is
# filtered out here.
iw_list_domains() {

    if [ -z "${IW_TOOL:-}" ] || [ ! -x "$IW_TOOL" ]; then
        return
    fi

    timeout "$TOOL_TIMEOUT" "$IW_TOOL" list domain 2>/dev/null \
        | tr -d '\r' \
        | grep -v '^##.*##$' \
        | grep -v '^\s*$'

}

# Domain-scoped variant of iw_get - for properties that only make sense per
# domain (Daily Send Limit, Disk Quota, etc - the "D_*" properties in
# tool.help). Takes the domain name explicitly so callers can loop over
# iw_list_domains() output instead of relying on a static config value.
#
# Usage: iw_get_domain "<domain>" "<D_property>" "<config file>" "<regex>" "<os cmd>"
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
        # BUGFIX: `tool display domain <domain> <prop>` prints the domain
        # name as a header line BEFORE "PropName: value" - grep for the
        # actual property line instead of blindly taking the first line
        # (which would be the domain name, parsing to an empty value).
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

# Low level tool.sh caller, with timeout and output parsing.
# IceWarp's tool.sh typically prints "PropertyName: value"
iw_tool_get() {

    local KEY="$1"
    local RAW

    RAW="$(timeout "$TOOL_TIMEOUT" "$IW_TOOL" display system "$KEY" 2>/dev/null)"

    # Strip CR (Windows-style line endings sometimes appear in tool.sh output)
    RAW="${RAW//$'\r'/}"

    printf '%s' "$RAW" | awk -F': ' '{print $2}' | head -n1

}

# Multi-line-safe variant - for properties whose value can legitimately
# span multiple lines (e.g. C_License_XML). iw_tool_get() above discards
# everything after the first line via `head -n1`, which is correct for
# ordinary single-line properties but silently truncates XML/multi-line
# ones down to just their opening tag. This strips only the "KEY: " prefix
# from line 1 and keeps every subsequent line intact.
iw_tool_get_multiline() {

    local KEY="$1"
    local RAW

    RAW="$(timeout "$TOOL_TIMEOUT" "$IW_TOOL" display system "$KEY" 2>/dev/null)"
    RAW="${RAW//$'\r'/}"

    printf '%s' "$RAW" | sed '1s/^[^:]*:[[:space:]]*//'

}

###############################################################################
# Collector execution wrapper - called from agent.sh for every collector file.
# Tracks per-collector status so failures are visible in the final report
# instead of silently producing empty fields.
###############################################################################

# NOTE on timeouts: collector_run itself is executed in the *current* shell
# (not a subshell/subprocess) so that collector_set can write into the shared
# DATA array. Wrapping it in `timeout` would lose that shared state. Instead,
# every potentially slow operation (tool.sh calls, OS command fallback) is
# already individually time-bounded inside iw_get/iw_tool_get. A collector
# that only uses iw_get can therefore never hang the whole agent for longer
# than TOOL_TIMEOUT per call. If a collector needs its own long-running OS
# command outside iw_get, it must wrap it with `timeout` itself.
run_collector() {

    local COLLECTOR_PATH="$1"
    local NAME="${COLLECTOR_PATH#$COLLECTOR_DIR/}"
    NAME="${NAME%.sh}"
    local ERR_FILE="/tmp/.collector_err.$$"

    # shellcheck disable=SC1090
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
