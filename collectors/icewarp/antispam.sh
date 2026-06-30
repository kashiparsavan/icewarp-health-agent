#!/bin/bash

# Same approach as antivirus.sh - no tool.sh property for "antispam rules
# last update timestamp" was found. Falls back to newest file mtime under
# IW_AS_DEFS_PATH. Verify this path against the real install.

collector_run() {

    local VALUE
    VALUE="$(iw_get "" "" "" \
        "find '${IW_AS_DEFS_PATH}' -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -n1 | cut -d. -f1 | xargs -I{} date -d @{} '+%F %T'")"

    collector_set "icewarp.antispam.last_update" "$VALUE"

}
