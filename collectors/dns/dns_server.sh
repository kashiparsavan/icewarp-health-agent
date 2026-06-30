#!/bin/bash

# Checklist: "Check DNS Server", "Test DNS Lookup"
collector_run() {

    collector_set "dns.configured_server" "$(iw_get "C_Mail_SMTP_General_DNSServer" "" "" "")"

    local TEST_HOST="${MAIL_HOSTNAME:-google.com}"
    local RESULT
    RESULT="$(timeout "$TOOL_TIMEOUT" dig +short "$TEST_HOST" 2>/dev/null | head -n1)"

    collector_set "dns.lookup_test.host" "$TEST_HOST"
    collector_set "dns.lookup_test.ok" "$([ -n "$RESULT" ] && echo true || echo false)"
    collector_set "dns.lookup_test.result" "$RESULT"

}
