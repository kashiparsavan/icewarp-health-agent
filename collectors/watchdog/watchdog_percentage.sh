#!/bin/bash
# collectors/watchdog/watchdog_percentage.sh

collector_run() {

    days_ago() {
        local date_str="${1:-}"
        [[ -z "$date_str" ]] && { echo "0"; return; }
        local date_epoch=$(date -d "$date_str" +%s 2>/dev/null)
        [[ -z "$date_epoch" ]] && { echo "0"; return; }
        echo $(( ( $(date +%s) - date_epoch ) / 86400 ))
    }

    # ----- Disk -----
    DISK_PCT=$(echo "${DATA[storage.root_fs.used_percent]:-0}" | sed 's/%//')
    if [[ "$DISK_PCT" =~ ^[0-9]+$ ]] && [[ "$DISK_PCT" -ge 80 ]]; then
        DATA["watchdog.disk.status"]="WARN"
        DATA["watchdog.disk.message"]="Disk usage is ${DISK_PCT}% (threshold: 80%)"
    elif [[ "$DISK_PCT" =~ ^[0-9]+$ ]]; then
        DATA["watchdog.disk.status"]="PASS"
        DATA["watchdog.disk.message"]="Disk usage is ${DISK_PCT}% (OK)"
    else
        DATA["watchdog.disk.status"]="INFO"
        DATA["watchdog.disk.message"]="Disk usage data not available"
    fi

    # ----- CPU -----
    LOAD1="${DATA[os.cpu.load1]:-0}"
    CORES="${DATA[os.cpu.count]:-1}"
    LOAD1=$(echo "$LOAD1" | tr ',' '.' | sed 's/[^0-9.]//g')
    [[ -z "$LOAD1" ]] && LOAD1="0"
    if [[ "$CORES" =~ ^[0-9]+$ ]] && [[ "$CORES" -gt 0 ]]; then
        CPU_PCT=$(awk -v l="$LOAD1" -v c="$CORES" 'BEGIN {printf "%.2f", (l/c)*100}')
        if (( $(echo "$CPU_PCT > 50" | bc -l 2>/dev/null) )); then
            DATA["watchdog.cpu.status"]="WARN"
            DATA["watchdog.cpu.message"]="CPU load (1-min) is ${CPU_PCT}% (threshold: 50%)"
        else
            DATA["watchdog.cpu.status"]="PASS"
            DATA["watchdog.cpu.message"]="CPU load (1-min) is ${CPU_PCT}% (OK)"
        fi
    else
        DATA["watchdog.cpu.status"]="INFO"
        DATA["watchdog.cpu.message"]="CPU count not available"
    fi

    # ----- Memory -----
    TOTAL="${DATA[os.memory.total_kb]:-0}"
    AVAIL="${DATA[os.memory.available_kb]:-0}"
    TOTAL=$(echo "$TOTAL" | sed 's/[^0-9]//g')
    AVAIL=$(echo "$AVAIL" | sed 's/[^0-9]//g')
    if [[ -n "$TOTAL" ]] && [[ -n "$AVAIL" ]] && [[ "$TOTAL" -gt 0 ]]; then
        MEM_PCT=$(awk -v t="$TOTAL" -v a="$AVAIL" 'BEGIN {printf "%.2f", ((t-a)/t)*100}')
        if (( $(echo "$MEM_PCT > 60" | bc -l 2>/dev/null) )); then
            DATA["watchdog.memory.status"]="WARN"
            DATA["watchdog.memory.message"]="Memory usage is ${MEM_PCT}% (threshold: 60%)"
        else
            DATA["watchdog.memory.status"]="PASS"
            DATA["watchdog.memory.message"]="Memory usage is ${MEM_PCT}% (OK)"
        fi
    else
        DATA["watchdog.memory.status"]="INFO"
        DATA["watchdog.memory.message"]="Memory data not available"
    fi

    # ----- OS Update -----
    LAST_UPDATE="${DATA[os.last_update_date]:-}"
    if [[ -n "$LAST_UPDATE" ]] && [[ "$LAST_UPDATE" != "null" ]]; then
        DAYS=$(days_ago "$LAST_UPDATE")
        if [[ "$DAYS" -gt 3 ]]; then
            DATA["watchdog.os_update.status"]="WARN"
            DATA["watchdog.os_update.message"]="OS last update was $DAYS days ago (threshold: 3 days)"
        else
            DATA["watchdog.os_update.status"]="PASS"
            DATA["watchdog.os_update.message"]="OS last update was $DAYS days ago (OK)"
        fi
    else
        DATA["watchdog.os_update.status"]="INFO"
        DATA["watchdog.os_update.message"]="OS last update date not available"
    fi

    # ----- Summary -----
    WARN_COUNT=0
    for key in "${!DATA[@]}"; do
        [[ "$key" == "watchdog."*".status" ]] && [[ "${DATA[$key]}" == "WARN" ]] && ((WARN_COUNT++))
    done
    DATA["watchdog.summary.warnings"]="$WARN_COUNT"
    if [[ "$WARN_COUNT" -eq 0 ]]; then
        DATA["watchdog.summary.overall"]="PASS"
    else
        DATA["watchdog.summary.overall"]="WARN"
    fi
}
