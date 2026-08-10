#!/bin/bash

# Checklist: "Number of Used Seats / License Max Users"
# Source: C_License_XML (confirmed in tool.help - "XML decrypted license").
# The seat/user-limit field's exact XML tag name is NOT confirmed - this is
# a best-effort grep across a few plausible tag names. If none match, this
# honestly reports "not found" rather than guessing a number.

collector_run() {
    local XML
    XML="$(iw_get "C_License_XML" "" "" "")"

    if [ -z "$XML" ]; then
        collector_set "icewarp.license.seats_info_available" "false"
        return
    fi

    collector_set "icewarp.license.seats_info_available" "true"

    local MAX_USERS
    MAX_USERS="$(echo "$XML" | grep -ioP '<(MaxUsers|Users|Seats|MaxAccounts)>\K[0-9]+' | head -n1)"
    collector_set "icewarp.license.max_users_raw" "$MAX_USERS"

    if [ -z "$MAX_USERS" ]; then
        collector_set "icewarp.license.max_users_note" "XML present but none of the guessed tag names (MaxUsers/Users/Seats/MaxAccounts) matched - real tag name unconfirmed, needs a sample XML to identify"
    fi

    # Used seats (actual mailbox count): no confirmed tool.sh property for
    # a direct count - would require enumerating mailboxes per domain,
    # which isn't attempted here to avoid an expensive/unreliable guess.
    collector_set "icewarp.license.used_seats_note" "not implemented - no confirmed tool.sh property for a direct mailbox count"
}
