#!/bin/bash

# Checklist items resolved here:
#   "Enable Daytime Clock Synchronization" -> C_System_Tools_AtomicClockSync_Enable
#   "Disable DIGEST-MD5"                   -> derived from C_Accounts_Policies_Auth_Schemes
#       (this property holds the list of allowed SASL auth schemes as a
#        string, e.g. "PLAIN;LOGIN;DIGEST-MD5;CRAM-MD5"; DIGEST-MD5 is
#        "disabled" when it's absent from that list - verified the checkbox
#        set [PLAIN, DIGEST-MD5, LOGIN, CRAM-MD5] in the live screenshot, so
#        this list format assumption should match, but please confirm the
#        exact separator/casing once tested live)

collector_run() {

    collector_set "icewarp.daytime_clock_sync.enabled" "$(iw_get "C_System_Tools_AtomicClockSync_Enable" "" "" "")"

    local SCHEMES
    SCHEMES="$(iw_get "C_Accounts_Policies_Auth_Schemes" "" "" "")"
    collector_set "security.auth_schemes.raw" "$SCHEMES"

    if [ -n "$SCHEMES" ]; then
        if echo "$SCHEMES" | grep -qi "DIGEST-MD5"; then
            collector_set "security.digest_md5.enabled" "true"
        else
            collector_set "security.digest_md5.enabled" "false"
        fi
    else
        collector_set "security.digest_md5.enabled" ""
    fi

}
