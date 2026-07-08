#!/bin/bash

# REWRITTEN per explicit request: scope narrowed to exactly the paths that
# matter (mail dir, archive dir, IceWarp install dir, / , /root) - no more
# scanning/reporting on every filesystem on the box. Sizes are now reported
# in human-readable GB (1 decimal place) instead of raw KB, alongside a
# clean used-percent. Raw KB values are dropped entirely - if finer
# precision is ever needed they can be re-added as extra fields without
# touching the GB fields.

# df -k output: Filesystem 1K-blocks Used Available Use% Mounted-on
_storage_check() {

    local LABEL="$1"
    local PATH_TO_CHECK="$2"
    local LINE

    if [ ! -d "$PATH_TO_CHECK" ]; then
        collector_set "storage.${LABEL}.status" "path_not_found"
        return
    fi

    LINE="$(timeout "$TOOL_TIMEOUT" df -kP "$PATH_TO_CHECK" 2>/dev/null | tail -n1)"

    if [ -z "$LINE" ]; then
        collector_set "storage.${LABEL}.status" "df_failed"
        return
    fi

    local DEVICE TOTAL_KB USED_KB AVAIL_KB USE_PCT MOUNT
    read -r DEVICE TOTAL_KB USED_KB AVAIL_KB USE_PCT MOUNT <<< "$LINE"
    USE_PCT="${USE_PCT%\%}"

    collector_set "storage.${LABEL}.path" "$PATH_TO_CHECK"
    collector_set "storage.${LABEL}.device" "$DEVICE"
    collector_set "storage.${LABEL}.mount" "$MOUNT"
    collector_set "storage.${LABEL}.total_gb" "$(awk -v kb="$TOTAL_KB" 'BEGIN{printf "%.1f", kb/1024/1024}')"
    collector_set "storage.${LABEL}.used_gb" "$(awk -v kb="$USED_KB" 'BEGIN{printf "%.1f", kb/1024/1024}')"
    collector_set "storage.${LABEL}.free_gb" "$(awk -v kb="$AVAIL_KB" 'BEGIN{printf "%.1f", kb/1024/1024}')"
    collector_set "storage.${LABEL}.used_percent" "$USE_PCT"
    collector_set "storage.${LABEL}.status" "$([ "$USE_PCT" -lt 90 ] 2>/dev/null && echo OK || echo WARNING)"

}

collector_run() {

    # Use the LIVE paths already resolved by icewarp/storage_paths.sh (which
    # runs earlier alphabetically) instead of the static config defaults -
    # otherwise this collector would reintroduce the exact staleness problem
    # already fixed there (an admin-changed path silently being ignored).
    local MAIL_PATH="${DATA[icewarp.path.mail]:-$IW_MAIL}"
    local ARCHIVE_PATH="${DATA[icewarp.path.archive]:-$IW_ARCHIVE}"

    _storage_check "mail" "$MAIL_PATH"
    _storage_check "archive" "$ARCHIVE_PATH"
    _storage_check "install" "${IW_HOME}"
    _storage_check "root_fs" "/"
    _storage_check "root_home" "/root"

}
