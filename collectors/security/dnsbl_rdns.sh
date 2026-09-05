#!/bin/bash

# Checklist items resolved here (Security/Anti-Spam section):
#   "Use DNSBL"                                  -> C_Mail_Security_Protection_DNSBL
#   "Close Connections for DNSBL Sessions"        -> C_Mail_Security_Protection_CloseDNSBLConn
#   "Reject if Originator's IP has no rDNS"       -> C_Mail_Security_Protection_RejectrDNS
#   "Reject if Originator's Domain Does Not Exist"-> C_Mail_Security_Protection_RejectMX
#       (closest available property: rejects when the domain has no MX
#        record, which is the practical equivalent of "doesn't exist" for
#        mail purposes - flagged for verification)
#   "Use IP Reputation"                           -> C_AS_IPreputationUse

collector_run() {

    collector_set "security.dnsbl.use" "$(iw_get "C_Mail_Security_Protection_DNSBL" "" "" "")"
    collector_set "security.dnsbl.close_sessions" "$(iw_get "C_Mail_Security_Protection_CloseDNSBLConn" "" "" "")"
    collector_set "security.reject_no_rdns" "$(iw_get "C_Mail_Security_Protection_RejectrDNS" "" "" "")"
    collector_set "security.reject_domain_no_mx" "$(iw_get "C_Mail_Security_Protection_RejectMX" "" "" "")"
    collector_set "security.ip_reputation.use" "$(iw_get "C_AS_IPreputationUse" "" "" "")"

}
