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

MODE="${1:-run}"

case "$MODE" in

    --list)

        list_collectors
        exit 0
        ;;

esac

agent_init

while IFS= read -r COLLECTOR
do

    source "$COLLECTOR"

    if declare -F collector_run >/dev/null
    then
        echo "[RUN ] ${COLLECTOR#$PROJECT_ROOT/}"
        collector_run
        unset -f collector_run
    fi

done < <(find "$COLLECTOR_DIR" -type f -name "*.sh" | sort)

build_json

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
