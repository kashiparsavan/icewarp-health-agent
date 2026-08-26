#!/bin/bash

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PROJECT_ROOT

CONFIG_DIR="${PROJECT_ROOT}/config"
LIB_DIR="${PROJECT_ROOT}/lib"
COLLECTOR_DIR="${PROJECT_ROOT}/collectors"
OUTPUT_DIR="${PROJECT_ROOT}/output"
LOG_DIR="${PROJECT_ROOT}/logs"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$LOG_DIR"

# Logging setup - each run gets a timestamped log file
LOG_FILE="${LOG_DIR}/agent_$(date +%Y%m%d_%H%M%S).log"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Agent started (PID $$)"

for LIB in "$LIB_DIR"/*.sh
do
    [ -f "$LIB" ] && source "$LIB"
done

# Source only agent.conf and icewarp.conf, skip checklist.conf.pdf
for CFG in "$CONFIG_DIR"/*.conf
do
    [ -f "$CFG" ] || continue
    case "$(basename "$CFG")" in
        agent.conf|icewarp.conf) source "$CFG" ;;
        *) log "Skipping config file: $CFG" ;;
    esac
done

MODE="run"
COLLECTOR_FILTER=""
COLLECTOR_FILTER_FILE=""
ARG_COMPANY=""
ARG_TECHNICIAN=""

for ARG in "$@"; do
    case "$ARG" in
        --list) MODE="--list" ;;
        --report) MODE="--report" ;;
        --only=*) COLLECTOR_FILTER="${ARG#--only=}" ;;
        --only-file=*) COLLECTOR_FILTER_FILE="${ARG#--only-file=}" ;;
        --company=*) ARG_COMPANY="${ARG#--company=}" ;;
        --technician=*) ARG_TECHNICIAN="${ARG#--technician=}" ;;
    esac
done

if [ -n "$COLLECTOR_FILTER_FILE" ]; then
    if [ ! -f "$COLLECTOR_FILTER_FILE" ]; then
        log "ERROR: --only-file '$COLLECTOR_FILTER_FILE' not found"
        exit 1
    fi
    FILE_PATTERNS="$(grep -v '^\s*#' "$COLLECTOR_FILTER_FILE" | grep -v '^\s*$' | tr '\n' ',' | sed 's/,$//')"
    if [ -n "$COLLECTOR_FILTER" ] && [ -n "$FILE_PATTERNS" ]; then
        COLLECTOR_FILTER="${COLLECTOR_FILTER},${FILE_PATTERNS}"
    elif [ -n "$FILE_PATTERNS" ]; then
        COLLECTOR_FILTER="$FILE_PATTERNS"
    fi
fi

case "$MODE" in
    --list)
        list_collectors
        exit 0
        ;;
esac

acquire_lock
trap release_lock EXIT

agent_init

if [ -n "$ARG_TECHNICIAN" ]; then
    DATA["general.technician"]="$ARG_TECHNICIAN"
else
    DATA["general.technician"]="${TECHNICIAN_NAME:-Not Specified}"
fi

while IFS= read -r COLLECTOR
do
    if [ -n "$COLLECTOR_FILTER" ]; then
        MATCH=0
        IFS=',' read -ra _ONLY_FILTERS <<< "$COLLECTOR_FILTER"
        for F in "${_ONLY_FILTERS[@]}"; do
            [[ "$COLLECTOR" == *"$F"* ]] && MATCH=1
        done
        [ "$MATCH" -eq 0 ] && continue
    fi

    log "Running collector: ${COLLECTOR#$PROJECT_ROOT/}"
    run_collector "$COLLECTOR"
done < <(find "$COLLECTOR_DIR" -type f -name "*.sh" | sort)

if [ -n "$ARG_COMPANY" ]; then
    DATA["general.company"]="$ARG_COMPANY"
elif [ -z "${DATA[general.company]:-}" ]; then
    DATA["general.company"]="${DATA[domain.primary.name]:-${DATA[agent.hostname]:-Unknown Host}}"
fi

log "Evaluating health"
evaluate_health

log "Building JSON"
build_json

if [ "${BUILD_PDF:-1}" = "1" ]; then
    log "Building PDF report"
    build_pdf
fi

if [ "${BUILD_MANAGEMENT_PDF:-1}" = "1" ]; then
    log "Building management PDF"
    build_management_pdf
fi

if [ "$MODE" = "--report" ]; then
    print_report
    log "Agent finished (report mode)"
    exit 0
fi

send_json

echo
echo "========================================"
echo "Agent Finished"
echo "Output : ${OUTPUT_JSON}"
echo "Keys   : ${#DATA[@]}"
echo "========================================"
echo

log "Agent finished (normal mode)"
