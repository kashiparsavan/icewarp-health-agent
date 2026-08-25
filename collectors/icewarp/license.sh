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

    # Fallback: the flat C_License_TrialExpire property has been observed
    # to come back empty on a real server that genuinely has an active
    # trial license. iw_get's underlying tool.sh reader truncates
    # multi-line values (like XML) to their first line via head -n1 - fine
    # for ordinary flat properties, but silently destroys XML content. Use
    # the multi-line-safe reader here and grep the full XML as a cross-check.
    if [ -z "$TRIAL_EXPIRE" ]; then
        local XML
        XML="$(iw_tool_get_multiline "C_License_XML")"
        TRIAL_EXPIRE="$(echo "$XML" | grep -ioP '<(TrialExpire|TrialExpiration|Expire|ExpirationDate)>\K[^<]+' | head -n1)"
        [ -n "$TRIAL_EXPIRE" ] && collector_set "icewarp.license.trial_expiration_source" "XML fallback (flat property was empty)"
    fi

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
