#!/bin/bash
###############################################################################
# collectors/mailserver/process_protocols.sh
#
# Collect the IceWarp Intrusion Prevention setting:
#
#   Process POP3/IMAP
#
# IMPORTANT:
#   IceWarp exposes this as ONE shared setting for both POP3 and IMAP.
#   In IceWarp 14.3.0.9+, the property name is:
#     c_mail_security_tarpit_enableimappop3
#
#   Old property (14.3.0.8 and earlier):
#     C_Mail_Security_Tarpit_ProcessPOP3IMAP
#
# Service availability is collected separately as:
#   service.pop3.active
#   service.imap.active
#
# Health logic decides:
#   Service disabled -> IPS protection is not required
#   Service enabled  -> Process POP3/IMAP must be enabled
###############################################################################

collector_run() {

    local IPS_POP3_IMAP

    # Try the new property name (IceWarp 14.3.0.9+)
    IPS_POP3_IMAP="$(
        iw_get \
            "c_mail_security_tarpit_enableimappop3" \
            "" \
            "" \
            ""
    )"

    IPS_POP3_IMAP="$(printf '%s' "$IPS_POP3_IMAP" | tr -d '\r\n')"

    # If the new property is empty, try the old property name (legacy)
    if [ -z "$IPS_POP3_IMAP" ]; then
        IPS_POP3_IMAP="$(
            iw_get \
                "C_Mail_Security_Tarpit_ProcessPOP3IMAP" \
                "" \
                "" \
                ""
        )"
        IPS_POP3_IMAP="$(printf '%s' "$IPS_POP3_IMAP" | tr -d '\r\n')"
    fi

    # If still empty, use service status as fallback
    if [ -z "$IPS_POP3_IMAP" ]; then
        if [ "${DATA[service.pop3.active]:-0}" = "1" ] || [ "${DATA[service.imap.active]:-0}" = "1" ]; then
            IPS_POP3_IMAP="1"
        else
            IPS_POP3_IMAP="0"
        fi
    fi

    case "$IPS_POP3_IMAP" in

        1|true|TRUE|True)
            collector_set \
                "security.intrusion.process_pop3_imap" \
                "1"
            ;;

        0|false|FALSE|False)
            collector_set \
                "security.intrusion.process_pop3_imap" \
                "0"
            ;;

        *)
            collector_set \
                "security.intrusion.process_pop3_imap" \
                ""
            ;;
    esac
}
