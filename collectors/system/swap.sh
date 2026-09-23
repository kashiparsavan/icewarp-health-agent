#!/bin/bash

collector_run() {
    local SWAP_TOTAL=0
    local SWAP_USED=0
    local SWAP_HISTORY=""
    local SWAP_MESSAGES=""

    if command -v swapon &>/dev/null; then
        SWAP_TOTAL=$(swapon -s 2>/dev/null | awk 'NR>1 {sum += $3} END {print sum}')
        SWAP_USED=$(swapon -s 2>/dev/null | awk 'NR>1 {sum += $4} END {print sum}')
    fi

    if [ -z "$SWAP_TOTAL" ] || [ "$SWAP_TOTAL" -eq 0 ]; then
        collector_set "system.swap.total_kb" "0"
        collector_set "system.swap.used_kb" "0"
        collector_set "system.swap.used_percent" "0"
        collector_set "system.swap.status" "PASS"
        collector_set "system.swap.message" "No swap configured"
        return
    fi

    if command -v sar &>/dev/null; then
        SWAP_HISTORY=$(sar -S 2>/dev/null | tail -n +3 | head -7)
    fi

    if [ -z "$SWAP_HISTORY" ] && command -v journalctl &>/dev/null; then
        SWAP_MESSAGES=$(journalctl --since "7 days ago" 2>/dev/null | grep -i swap | head -5)
    fi

    local USED_PERCENT=0
    if [ "$SWAP_TOTAL" -gt 0 ]; then
        USED_PERCENT=$(awk -v u="$SWAP_USED" -v t="$SWAP_TOTAL" 'BEGIN{printf "%.2f", (u/t)*100}')
    fi

    collector_set "system.swap.total_kb" "$SWAP_TOTAL"
    collector_set "system.swap.used_kb" "$SWAP_USED"
    collector_set "system.swap.used_percent" "$USED_PERCENT"
    collector_set "system.swap.history" "${SWAP_HISTORY:-$SWAP_MESSAGES}"

    if [ -n "$SWAP_HISTORY" ] || [ -n "$SWAP_MESSAGES" ]; then
        collector_set "system.swap.status" "CRITICAL"
        collector_set "system.swap.message" "Swap usage detected in the last 7 days"
    elif [ "$USED_PERCENT" != "0.00" ]; then
        collector_set "system.swap.status" "CRITICAL"
        collector_set "system.swap.message" "Swap is currently in use (${USED_PERCENT}%)"
    else
        collector_set "system.swap.status" "PASS"
        collector_set "system.swap.message" "No swap usage detected"
    fi
}
