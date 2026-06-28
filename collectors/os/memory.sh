#!/bin/bash

collector_run() {

    while read KEY VALUE UNIT
    do
        case "$KEY" in
            MemTotal:)
                collector_set "os.memory.total_kb" "$VALUE"
                ;;
            MemAvailable:)
                collector_set "os.memory.available_kb" "$VALUE"
                ;;
            SwapTotal:)
                collector_set "os.swap.total_kb" "$VALUE"
                ;;
            SwapFree:)
                collector_set "os.swap.free_kb" "$VALUE"
                ;;
        esac
    done < /proc/meminfo

}
