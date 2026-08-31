#!/bin/bash
# collector_tester.sh - Test a single collector
# Usage: ./collector_tester.sh <collector_name>
# Example: ./collector_tester.sh resolver_external

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT

# ---- Required environment variables ----
export AGENT_VERSION="${AGENT_VERSION:-0.3.0}"
export TOOL_TIMEOUT="${TOOL_TIMEOUT:-5}"
export IW_TOOL="${IW_TOOL:-/opt/icewarp/tool.sh}"
export BUILD_PDF=0
export BUILD_MANAGEMENT_PDF=0
export SEND_DATA=0

COLLECTOR_NAME="${1:-}"

if [ -z "$COLLECTOR_NAME" ]; then
    echo "Usage: $0 <collector_name>"
    echo "Example: $0 resolver_external"
    echo ""
    echo "Available collectors:"
    find "$PROJECT_ROOT/collectors" -type f -name "*.sh" -printf "%f\n" | sed 's/\.sh$//' | sort
    exit 1
fi

# Find the collector file
COLLECTOR_FILE=$(find "$PROJECT_ROOT/collectors" -type f -name "${COLLECTOR_NAME}.sh" | head -1)

if [ ! -f "$COLLECTOR_FILE" ]; then
    echo "ERROR: Collector '${COLLECTOR_NAME}' not found!"
    echo "Search path: $PROJECT_ROOT/collectors"
    exit 1
fi

echo "========================================"
echo "Testing Collector: $COLLECTOR_NAME"
echo "File: $COLLECTOR_FILE"
echo "========================================"
echo ""

# Load libraries
for LIB in "$PROJECT_ROOT/lib"/*.sh; do
    [ -f "$LIB" ] && source "$LIB"
done

# Initialize environment
agent_init

# Reset DATA for this collector test
DATA=()

# Run the collector
echo "[RUN] Executing collector..."
source "$COLLECTOR_FILE"
collector_run

# Display results
echo ""
echo "========================================"
echo "Results (${#DATA[@]} keys):"
echo "========================================"

if [ ${#DATA[@]} -eq 0 ]; then
    echo "No data collected. Check if collector_run() sets DATA[] correctly."
else
    for KEY in $(printf '%s\n' "${!DATA[@]}" | sort); do
        printf "%-45s : %s\n" "$KEY" "${DATA[$KEY]}"
    done
fi

echo ""
echo "========================================"
echo "Collector test completed."
