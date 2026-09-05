#!/bin/bash

# Checklist: "Check DNS Server", "Test DNS Lookup"
collector_run() {

    collector_set "dns.configured_server" "$(iw_get "C_Mail_SMTP_General_DNSServer" "" "" "")"

    local TEST_HOST
    TEST_HOST="$(resolve_mail_hostname)"
    [ -z "$TEST_HOST" ] && TEST_HOST="google.com"

    local RESULT
    RESULT="$(dig_resilient "$TEST_HOST" | head -n1)"

    collector_set "dns.lookup_test.host" "$TEST_HOST"
    collector_set "dns.lookup_test.ok" "$([ -n "$RESULT" ] && echo true || echo false)"
    collector_set "dns.lookup_test.result" "$RESULT"

    # Separate, genuinely external resolver health check - resolving our
    # OWN domain only proves our own records exist, not that the resolver
    # can generally resolve arbitrary destination domains (what actually
    # matters for outbound delivery and PTR-checking senders).
    local EXTERNAL_TARGETS=("google.com" "cloudflare.com" "microsoft.com")
    local T EXT_RESULT="" EXT_HOST=""
    for T in "${EXTERNAL_TARGETS[@]}"; do
        EXT_RESULT="$(dig_resilient "$T" | head -n1)"
        if [ -n "$EXT_RESULT" ]; then
            EXT_HOST="$T"
            break
        fi
    done
    collector_set "dns.resolver.external_test_host" "${EXT_HOST:-none resolved}"
    collector_set "dns.resolver.external_test_ok" "$([ -n "$EXT_RESULT" ] && echo true || echo false)"

}
