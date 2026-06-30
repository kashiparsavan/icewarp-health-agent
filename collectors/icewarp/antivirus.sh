#!/bin/bash

# Checklist: "Antivirus Last Update"
#
# CORRECTED after live verification against IceWarp WebAdmin
# (System > Anti-Virus > General):
#   tool.sh property C_AV_Info_UpdateDate is EXACTLY the field shown as
#   "Last update date" in the admin console - confirmed against a live
#   screenshot (UI showed 23-6-26, matching this property's value).
#
# This is now the primary source, per the project's own priority rule
# (tool.sh first). The previous approach (parsing sophos/update.json
# directly) is kept only as a fallback for installs where this property
# isn't available, but is no longer primary - going directly to tool.sh
# avoids any ambiguity about which timestamp field (ide/vdl/linux64/...)
# corresponds to what the admin console actually displays.

IW_SOPHOS_PATH="${IW_SOPHOS_PATH:-${IW_HOME}/sophos}"

collector_run() {

    local UPDATE_DATE
    local UPDATE_VERSION
    local UPDATE_SIZE

    UPDATE_DATE="$(iw_get "C_AV_Info_UpdateDate" "" "" "")"
    UPDATE_VERSION="$(iw_get "C_AV_Info_UpdateVersion" "" "" "")"
    UPDATE_SIZE="$(iw_get "C_AV_Info_UpdateSize" "" "" "")"

    if [ -n "$UPDATE_DATE" ]; then
        collector_set "icewarp.antivirus.last_update" "$UPDATE_DATE"
        collector_set "icewarp.antivirus.last_update_source" "tool_sh"
        collector_set "icewarp.antivirus.db_version" "$UPDATE_VERSION"
        collector_set "icewarp.antivirus.last_update_size_bytes" "$UPDATE_SIZE"
        return
    fi

    # --- fallback: sophos/update.json "ide" field (verified to match the
    # tool.sh property in our test case) ---
    local JSON_FILE="${IW_SOPHOS_PATH}/update.json"
    local IDE_TS=""

    if [ -f "$JSON_FILE" ]; then
        IDE_TS="$(grep -oP '"ide"\s*:\s*\K[0-9]+' "$JSON_FILE" 2>/dev/null)"
    fi

    if [ -n "$IDE_TS" ]; then
        collector_set "icewarp.antivirus.last_update" "$(date -d @"$IDE_TS" '+%F %T' 2>/dev/null)"
        collector_set "icewarp.antivirus.last_update_source" "sophos_update_json_ide"
    else
        collector_set "icewarp.antivirus.last_update" ""
        collector_set "icewarp.antivirus.last_update_source" "not_found"
    fi

    local INFO_FILE="${IW_SOPHOS_PATH}/avdbinfo.dat"
    if [ -f "$INFO_FILE" ]; then
        collector_set "icewarp.antivirus.db_version" "$(tr -d '\0' < "$INFO_FILE" | head -c 100 | tr -d '\r\n')"
    fi

}
