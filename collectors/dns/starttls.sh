#!/bin/bash

# Checklist: "Check TLS & StartTLS" - this is a live protocol-level check,
# not a config lookup, so it always uses the OS-command layer.
collector_run() {

    local HOST="${MAIL_HOSTNAME:-localhost}"
    local RESULT

    RESULT="$(echo -e "QUIT\r\n" | timeout "$TOOL_TIMEOUT" openssl s_client -starttls smtp -connect "${HOST}:25" 2>&1)"

    if echo "$RESULT" | grep -qi "Verify return code"; then
        collector_set "smtp.starttls_live_test" "true"
    else
        collector_set "smtp.starttls_live_test" "false"
    fi

}
