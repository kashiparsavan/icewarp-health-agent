#!/bin/bash
set -e

PROJECT_ROOT="/root/iceauto"
export PROJECT_ROOT

CONFIG_DIR="${PROJECT_ROOT}/config"
LIB_DIR="${PROJECT_ROOT}/lib"
COLLECTOR_DIR="${PROJECT_ROOT}/collectors"
OUTPUT_DIR="${PROJECT_ROOT}/output"
LOG_DIR="${PROJECT_ROOT}/logs"

echo "=== DEBUG: Checking paths ==="
echo "PROJECT_ROOT=$PROJECT_ROOT"
echo "COLLECTOR_DIR=$COLLECTOR_DIR"
echo "LIB_DIR=$LIB_DIR"

echo ""
echo "=== DEBUG: Checking if collectors exist ==="
find "$COLLECTOR_DIR" -type f -name "*.sh" | head -5
echo "Total collectors: $(find "$COLLECTOR_DIR" -type f -name "*.sh" | wc -l)"

echo ""
echo "=== DEBUG: Sourcing common.sh ==="
source "$LIB_DIR/common.sh"
echo "common.sh sourced successfully"

echo ""
echo "=== DEBUG: agent_init ==="
agent_init
echo "agent_init done. DATA size: ${#DATA[@]}"

echo ""
echo "=== DEBUG: Running a single collector (general/date.sh) ==="
if [ -f "$COLLECTOR_DIR/general/date.sh" ]; then
    echo "Collector exists"
    source "$COLLECTOR_DIR/general/date.sh"
    collector_run
    echo "DATE collector result: ${DATA[general.date]}"
else
    echo "Collector general/date.sh NOT found!"
fi

echo ""
echo "=== DEBUG: Running all collectors (dry run) ==="
for COLLECTOR in $(find "$COLLECTOR_DIR" -type f -name "*.sh" | sort); do
    echo "  Found: ${COLLECTOR#$PROJECT_ROOT/}"
done

echo ""
echo "=== DEBUG: Done ==="
