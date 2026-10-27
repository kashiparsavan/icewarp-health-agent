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

    # Fallback 1: the flat C_License_TrialExpire property has been observed
    # to come back empty on a real server that genuinely has an active
    # trial license. Use the multi-line-safe reader and grep the full XML.
    if [ -z "$TRIAL_EXPIRE" ]; then
        local XML
        XML="$(iw_tool_get_multiline "C_License_XML")"
        TRIAL_EXPIRE="$(echo "$XML" | grep -ioP '<(TrialExpire|TrialExpiration|Expire|ExpirationDate)>\K[^<]+' | head -n1)"
        [ -n "$TRIAL_EXPIRE" ] && collector_set "icewarp.license.trial_expiration_source" "XML fallback (flat property was empty)"
    fi

    # Fallback 2: check for LicenseExpiration in XML (some versions use different tag)
    if [ -z "$TRIAL_EXPIRE" ]; then
        TRIAL_EXPIRE="$(echo "$XML" | grep -ioP '<LicenseExpiration>\K[^<]+' | head -n1)"
        [ -n "$TRIAL_EXPIRE" ] && collector_set "icewarp.license.trial_expiration_source" "XML LicenseExpiration tag"
    fi

    # Fallback 3: check license.xml file directly if it exists
    if [ -z "$TRIAL_EXPIRE" ] && [ "$FILE_EXISTS" = "true" ]; then
        TRIAL_EXPIRE="$(grep -ioP '<(TrialExpire|TrialExpiration|Expire|ExpirationDate|LicenseExpiration)>\K[^<]+' /opt/icewarp/license.xml 2>/dev/null | head -n1)"
        [ -n "$TRIAL_EXPIRE" ] && collector_set "icewarp.license.trial_expiration_source" "license.xml file direct read"
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
