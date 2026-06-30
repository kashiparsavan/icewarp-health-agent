#!/bin/bash

# Checklist items covered here:
#   "Relay Only if Originator's Domain is Local" -> C_Mail_Security_Protection_LocalDomain
#   Relay IP allow-list                          -> C_Mail_Security_Relay_IPList
#   Open/Close relay mode                        -> C_Mail_Security_Relay_RelayMode
#
# NOTE: there is no global "list of relayed domains" property in tool.help;
# domain-level relaying in IceWarp is implicit (any locally hosted domain).
# This collector reports the relay *mode/policy*, not a domain list. The old
# "smtp.relay.domains" key is dropped as misleading - replaced by the keys
# below.

collector_run() {

    local MODE
    local LOCAL_ONLY
    local IP_LIST

    MODE="$(iw_get "C_Mail_Security_Relay_RelayMode" "" "" "")"
    LOCAL_ONLY="$(iw_get "C_Mail_Security_Protection_LocalDomain" "" "" "")"
    IP_LIST="$(iw_get "C_Mail_Security_Relay_IPList" "" "" "")"

    collector_set "smtp.relay.mode" "$MODE"
    collector_set "smtp.relay.local_domain_only" "$LOCAL_ONLY"
    collector_set "smtp.relay.allowed_ips" "$IP_LIST"

}
