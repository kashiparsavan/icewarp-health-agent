#!/bin/bash

# Checklist: "IceWarp Expiration Date"
# Properties verified in tool.help:
#   C_LicenseStatus        - numeric status code
#   C_License_Type         - onpremise/cloud/saas
#   C_License_TrialExpire  - trial expiration date (only set for trial licenses)

collector_run() {

    local STATUS_CODE
    local LIC_TYPE
    local TRIAL_EXPIRE
    local FILE_EXISTS="false"

    [ -f /opt/icewarp/license.xml ] && FILE_EXISTS="true"

    STATUS_CODE="$(iw_get "C_LicenseStatus" "" "" "")"
    LIC_TYPE="$(iw_get "C_License_Type" "" "" "")"
    TRIAL_EXPIRE="$(iw_get "C_License_TrialExpire" "" "" "")"

    collector_set "icewarp.license.file_present" "$FILE_EXISTS"
    collector_set "icewarp.license.status_code" "$STATUS_CODE"
    collector_set "icewarp.license.type" "$LIC_TYPE"
    collector_set "icewarp.license.trial_expiration" "$TRIAL_EXPIRE"

    # Keep old key for backward compatibility with anything already reading it
    if [ -n "$STATUS_CODE" ]; then
        collector_set "icewarp.license.status" "ok"
    elif [ "$FILE_EXISTS" = "true" ]; then
        collector_set "icewarp.license.status" "installed"
    else
        collector_set "icewarp.license.status" "not_found"
    fi

}
