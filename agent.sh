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

for LIB in "$LIB_DIR"/*.sh
do
    [ -f "$LIB" ] && source "$LIB"
done

for CFG in "$CONFIG_DIR"/*.conf
do
    [ -f "$CFG" ] && source "$CFG"
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

# --only-file: one filter pattern per line (blank lines and lines starting
# with # are ignored). Merged with --only if both are given.
if [ -n "$COLLECTOR_FILTER_FILE" ]; then
    if [ ! -f "$COLLECTOR_FILTER_FILE" ]; then
        echo "[ERROR] --only-file: '$COLLECTOR_FILTER_FILE' not found" >&2
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

    echo "[RUN ] ${COLLECTOR#$PROJECT_ROOT/}"
    run_collector "$COLLECTOR"

done < <(find "$COLLECTOR_DIR" -type f -name "*.sh" | sort)

# Company Name: CLI flag wins, then whatever a collector already set (e.g.
# COMPANY_NAME in config/agent.conf via agent_init), then the actual
# IceWarp-configured domain (domain.primary.name, only available now that
# the collector loop has run), then the OS hostname, then a final fallback.
# Deliberately resolved AFTER the collector loop, not right after agent_init -
# domain.primary.name doesn't exist yet at that point.
if [ -n "$ARG_COMPANY" ]; then
    DATA["general.company"]="$ARG_COMPANY"
elif [ -z "${DATA[general.company]:-}" ]; then
    DATA["general.company"]="${DATA[domain.primary.name]:-${DATA[agent.hostname]:-Unknown Host}}"
fi

evaluate_health
build_json

if [ "${BUILD_PDF:-1}" = "1" ]; then
    build_pdf
fi

if [ "${BUILD_MANAGEMENT_PDF:-1}" = "1" ]; then
    build_management_pdf
fi

if [ "$MODE" = "--report" ]
then
    print_report
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
