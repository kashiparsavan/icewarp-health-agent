#!/bin/bash
# collectors/security/antispam_old_folders.sh
# Now checks /opt/icewarp/cyren/ folder instead of antispam folders.
# OK: folder does not exist OR exists and is empty
# WARN: folder exists and contains files/directories

collector_run() {

    local CYREN_DIR="/opt/icewarp/cyren"

    collector_set "security.cyren_folder.checked" "true"

    # Check if directory exists
    if [ ! -d "$CYREN_DIR" ]; then
        collector_set "security.cyren_folder.status" "OK"
        collector_set "security.cyren_folder.message" "Folder $CYREN_DIR does not exist (OK)"
        return
    fi

    # Directory exists, check if it's empty
    local CONTENT_COUNT
    CONTENT_COUNT="$(find "$CYREN_DIR" -mindepth 1 2>/dev/null | head -1 | wc -l)"

    if [ "$CONTENT_COUNT" -eq 0 ]; then
        collector_set "security.cyren_folder.status" "OK"
        collector_set "security.cyren_folder.message" "Folder $CYREN_DIR exists but is empty (OK)"
    else
        collector_set "security.cyren_folder.status" "WARN"
        collector_set "security.cyren_folder.message" "Folder $CYREN_DIR exists and contains files/directories (needs cleanup)"
    fi

}
