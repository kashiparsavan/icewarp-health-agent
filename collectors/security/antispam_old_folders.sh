#!/bin/bash

# Checklist: "Remove Old AntiSpam Folders"
#
# This is fundamentally a cleanup ACTION, not a config check - and this
# agent is read-only by design (reports state, never modifies the server).
# So instead of a yes/no, this reports real diagnostic numbers: how many
# antispam-related subfolders exist under IceWarp's antispam directory and
# how old the oldest ones are, so a technician can decide whether cleanup
# is actually needed - without the agent silently deleting anything.
#
# Path is derived from icewarp.home (already collected) + "antispam", the
# standard IceWarp layout - not from a dedicated tool.sh property (none
# found for this specific path).

collector_run() {

    local CANDIDATES=(
        "${DATA[icewarp.home]:-}/antispam"
        "${DATA[icewarp.home]:-}/AntiSpam"
        "${DATA[icewarp.home]:-}/spam"
        "${DATA[icewarp.home]:-}/Spam"
    )

    local AS_DIR="" C
    for C in "${CANDIDATES[@]}"; do
        if [ -n "$C" ] && [ -d "$C" ]; then
            AS_DIR="$C"
            break
        fi
    done

    if [ -z "$AS_DIR" ]; then
        collector_set "security.antispam_folders.checked" "false"
        collector_set "security.antispam_folders.reason" "none of the checked paths exist: ${CANDIDATES[*]} - no confirmed tool.sh property for this location"
        return
    fi

    collector_set "security.antispam_folders.checked" "true"
    collector_set "security.antispam_folders.path" "$AS_DIR"

    local TOTAL_COUNT
    TOTAL_COUNT="$(find "$AS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
    collector_set "security.antispam_folders.total_count" "$TOTAL_COUNT"

    # folders not modified in 90+ days - reasonable "stale, safe to review" threshold
    local OLD_COUNT
    OLD_COUNT="$(find "$AS_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +90 2>/dev/null | wc -l)"
    collector_set "security.antispam_folders.old_count_90d" "$OLD_COUNT"

    local TOTAL_SIZE
    TOTAL_SIZE="$(timeout "$TOOL_TIMEOUT" du -sh "$AS_DIR" 2>/dev/null | awk '{print $1}')"
    collector_set "security.antispam_folders.total_size" "$TOTAL_SIZE"

}
