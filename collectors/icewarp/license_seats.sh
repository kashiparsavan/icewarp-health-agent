#!/bin/bash

# Checklist: "Number of Used Seats / License Max Users"
# Source: C_License_XML (confirmed in tool.help - "XML decrypted license").
# The seat/user-limit field's exact XML tag name is NOT confirmed - this is
# a best-effort grep across a few plausible tag names. If none match, this
# honestly reports "not found" rather than guessing a number.

collector_run() {
    local XML
    XML="$(iw_tool_get_multiline "C_License_XML")"

    if [ -z "$XML" ]; then
        collector_set "icewarp.license.seats_info_available" "false"
        return
    fi

    collector_set "icewarp.license.seats_info_available" "true"
    collector_set "icewarp.license.xml_full_length" "${#XML}"

    local MAX_USERS
    MAX_USERS="$(echo "$XML" | grep -ioP '<(MaxUsers|Users|Seats|MaxAccounts|MaxMailboxes|Mailboxes|Accounts|UserCount|NumUsers|LicenseUsers|MaxLicUsers)>\K[0-9]+' | head -n1)"
    collector_set "icewarp.license.max_users_raw" "$MAX_USERS"

    if [ -z "$MAX_USERS" ]; then
        MAX_USERS="$(echo "$XML" | grep -ioP '(?:MaxUsers|Users|Seats|Accounts)[^0-9]{1,20}\K[0-9]+' | head -n1)"
        collector_set "icewarp.license.max_users_raw" "$MAX_USERS"
    fi

    # Cross-check for trial info directly in the XML, since the flat
    # C_License_TrialExpire property can come back empty even on a real
    # active trial (seen on a live server: 30-day trial with ~13 days
    # left, but the flat property returned nothing).
    local TRIAL_DAYS TRIAL_EXP
    TRIAL_DAYS="$(echo "$XML" | grep -ioP '<(TrialDays|Trial_Days|DaysLeft|TrialDaysLeft)>\K[0-9]+' | head -n1)"
    TRIAL_EXP="$(echo "$XML" | grep -ioP '<(TrialExpire|TrialExpiration|Expire|ExpirationDate)>\K[^<]+' | head -n1)"
    collector_set "icewarp.license.xml_trial_days" "$TRIAL_DAYS"
    collector_set "icewarp.license.xml_trial_expiration" "$TRIAL_EXP"

    if [ -z "$MAX_USERS" ] && [ -z "$TRIAL_DAYS" ] && [ -z "$TRIAL_EXP" ]; then
        collector_set "icewarp.license.max_users_note" "none of the guessed tag/attribute names matched - real format unconfirmed"
        collector_set "icewarp.license.xml_snippet" "$(echo "$XML" | head -c 800)"
    fi

    # Used seats (actual mailbox count): no confirmed tool.sh property for
    # a direct count - would require enumerating mailboxes per domain,
    # which isn't attempted here to avoid an expensive/unreliable guess.
    collector_set "icewarp.license.used_seats_note" "not implemented - no confirmed tool.sh property for a direct mailbox count"
}
