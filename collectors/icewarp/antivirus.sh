#!/bin/bash

# No tool.sh property exposes "antivirus definitions last update timestamp"
# directly. Best available signal: mtime of the newest file inside the
# antivirus definitions directory. Verify IW_AV_DEFS_PATH in icewarp.conf
# against the real install (path differs between AVG/Avast/Sophos/IWA).

collector_run() {

    local VALUE
    VALUE="$(iw_get "" "" "" \
        "find '${IW_AV_DEFS_PATH}' -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -n1 | cut -d. -f1 | xargs -I{} date -d @{} '+%F %T'")"

    collector_set "icewarp.antivirus.last_update" "$VALUE"

}
