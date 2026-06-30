#!/bin/bash

collector_run() {

    collect_storage "mail" \
        "$(/opt/icewarp/tool.sh get system C_System_Storage_Dir_MailPath 2>/dev/null | cut -d':' -f2- | xargs)"

    collect_storage "archive" \
        "$(/opt/icewarp/tool.sh get system C_System_Tools_AutoArchive_Path 2>/dev/null | cut -d':' -f2- | xargs)"

}

collect_storage() {

    local NAME="$1"
    local PATHNAME="$2"

    [ -z "$PATHNAME" ] && return

    PATHNAME="$(realpath "$PATHNAME" 2>/dev/null || echo "$PATHNAME")"

    collector_set "storage.paths.${NAME}" "$PATHNAME"

    local LINE

    LINE=$(findmnt -T "$PATHNAME" -n -o SOURCE,FSTYPE,TARGET)

    local DEVICE
    local FSTYPE
    local MOUNT

    DEVICE=$(echo "$LINE" | awk '{print $1}')
    FSTYPE=$(echo "$LINE" | awk '{print $2}')
    MOUNT=$(echo "$LINE" | awk '{print $3}')

    collector_set "storage.fs.${NAME}.device" "$DEVICE"
    collector_set "storage.fs.${NAME}.type" "$FSTYPE"
    collector_set "storage.fs.${NAME}.mount" "$MOUNT"

    local DF

    DF=$(df -P "$PATHNAME" | tail -1)

    collector_set "storage.fs.${NAME}.size"  "$(echo "$DF" | awk '{print $2}')"
    collector_set "storage.fs.${NAME}.used"  "$(echo "$DF" | awk '{print $3}')"
    collector_set "storage.fs.${NAME}.free"  "$(echo "$DF" | awk '{print $4}')"

    local USE

    USE=$(echo "$DF" | awk '{print $5}' | tr -d '%')

    collector_set "storage.fs.${NAME}.use" "$USE"

    local STATUS="OK"

    if [ "$USE" -ge 90 ]; then
        STATUS="CRITICAL"
    elif [ "$USE" -ge 80 ]; then
        STATUS="WARNING"
    fi

    collector_set "storage.fs.${NAME}.status" "$STATUS"

}
