#!/bin/bash

collector_run() {

    collector_set "os.cpu.count" "$(nproc)"

    read L1 L5 L15 _ < /proc/loadavg

    collector_set "os.cpu.load1" "$L1"
    collector_set "os.cpu.load5" "$L5"
    collector_set "os.cpu.load15" "$L15"

}
