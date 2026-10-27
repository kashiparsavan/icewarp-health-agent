#!/bin/bash

# Checklist: "IceWarp Expiration Date"
# Properties verified in tool.help:
#   C_LicenseStatus        - numeric status code
#   C_License_Type         - onpremise/cloud/saas
#   C_License_TrialExpire  - trial expiration date (only set for trial licenses)
#   C_License_ValidUntil   - expiration date for evaluation/trial
#   C_License_Evaluation_Expire - evaluation expiration

collector_run() {

    local STATUS_CODE
    local LIC_TYPE
    local TRIAL_EXPIRE
    local FILE_EXISTS="false"

    [ -f /opt/icewarp/license.xml ] && FILE_EXISTS="true"

    STATUS_CODE="$(iw_get "C_LicenseStatus" "" "" "")"
    LIC_TYPE="$(iw_get "C_License_Type" "" "" "")"
    TRIAL_EXPIRE="$(iw_get "C_License_TrialExpire" "" "" "")"

    # Try additional tool.sh keys for trial/evaluation expiration
    if [ -z "$TRIAL_EXPIRE" ]; then
        TRIAL_EXPIRE="$(iw_get "C_License_ValidUntil" "" "" "")"
    fi
    if [ -z "$TRIAL_EXPIRE" ]; then
        TRIAL_EXPIRE="$(iw_get "C_License_Evaluation_Expire" "" "" "")"
    fi
    if [ -z "$TRIAL_EXPIRE" ]; then
        TRIAL_EXPIRE="$(iw_get "C_License_TrialDaysRemaining" "" "" "")"
    fi

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

    # Fallback 4: parse "Days" remaining from XML and calculate expiration date
    if [ -z "$TRIAL_EXPIRE" ] && [ "$FILE_EXISTS" = "true" ]; then
        local DAYS_REMAINING
        # Try multiple possible tags for days remaining
        DAYS_REMAINING="$(grep -ioP '<(TrialDaysRemaining|DaysRemaining|EvaluationDays|TrialDays)>\K[^<]+' /opt/icewarp/license.xml 2>/dev/null | head -n1)"
        if [ -n "$DAYS_REMAINING" ] && [[ "$DAYS_REMAINING" =~ ^[0-9]+$ ]]; then
            # Calculate expiration date from days remaining
            local EXP_DATE
            EXP_DATE="$(date -d "+${DAYS_REMAINING} days" '+%Y-%m-%d' 2>/dev/null)"
            if [ -n "$EXP_DATE" ]; then
                TRIAL_EXPIRE="${EXP_DATE} (${DAYS_REMAINING} days remaining)"
                collector_set "icewarp.license.trial_expiration_source" "license.xml DaysRemaining calculation"
            fi
        fi
    fi

    # Fallback 5: try C_License_TrialDaysRemaining via tool.sh
    if [ -z "$TRIAL_EXPIRE" ]; then
        local TRIAL_DAYS
        TRIAL_DAYS="$(iw_get "C_License_TrialDaysRemaining" "" "" "")"
        if [ -n "$TRIAL_DAYS" ] && [[ "$TRIAL_DAYS" =~ ^[0-9]+$ ]]; then
            local EXP_DATE
            EXP_DATE="$(date -d "+${TRIAL_DAYS} days" '+%Y-%m-%d' 2>/dev/null)"
            if [ -n "$EXP_DATE" ]; then
                TRIAL_EXPIRE="${EXP_DATE} (${TRIAL_DAYS} days remaining)"
                collector_set "icewarp.license.trial_expiration_source" "C_License_TrialDaysRemaining calculation"
            fi
        fi
    fi

    # Determine license type: if TRIAL_EXPIRE is set or LIC_TYPE indicates trial/evaluation
    local FINAL_TYPE="${LIC_TYPE}"
    if [ -n "$TRIAL_EXPIRE" ] || echo "${LIC_TYPE:-}" | grep -iq "trial\|evaluation"; then
        FINAL_TYPE="Evaluation"
    fi

    collector_set "icewarp.license.file_present" "$FILE_EXISTS"
    collector_set "icewarp.license.status_code" "$STATUS_CODE"
    collector_set "icewarp.license.type" "${FINAL_TYPE:-${LIC_TYPE:-unknown}}"
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
