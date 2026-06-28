#!/bin/bash

collector_run() {

    while read FS SIZE USED AVAIL USEP MOUNT
    do

        [[ "$FS" == "Filesystem" ]] && continue

        KEY=$(echo "$MOUNT" | sed 's#^/##' | tr '/' '_' )

        [[ -z "$KEY" ]] && KEY="root"

        collector_set "os.disk.${KEY}.size" "$SIZE"
        collector_set "os.disk.${KEY}.used" "$USED"
        collector_set "os.disk.${KEY}.avail" "$AVAIL"
        collector_set "os.disk.${KEY}.use" "$USEP"

    done < <(df -hP)

}
