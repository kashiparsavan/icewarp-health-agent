#!/bin/bash
# collectors/mailserver/process_protocols.sh
# Check intrusion prevention for POP3 and IMAP separately

collector_run() {
    # Check POP3
    local POP3_ENABLED="${DATA[security.intrusion.process_pop3_imap]:-0}"
    if [[ "$POP3_ENABLED" == "1" ]] || [[ "$POP3_ENABLED" == "true" ]]; then
        DATA["security.intrusion.process_pop3"]="1"
    else
        DATA["security.intrusion.process_pop3"]="0"
    fi

    # Check IMAP (using same setting as POP3 for now - if they are separate in tool.help, adjust)
    local IMAP_ENABLED="${DATA[security.intrusion.process_pop3_imap]:-0}"
    if [[ "$IMAP_ENABLED" == "1" ]] || [[ "$IMAP_ENABLED" == "true" ]]; then
        DATA["security.intrusion.process_imap"]="1"
    else
        DATA["security.intrusion.process_imap"]="0"
    fi
}
