#!/bin/bash

# Checklist (Security/Anti-Spam section) - "Block IP Address that..." block,
# all verified directly against a live screenshot of
# Mail > Security > Intrusion Prevention.
#
# NOTE: in tool.help these are all grouped under the (somewhat confusingly
# named) "Tarpit" property family, even though several of them are simple
# hard-block rules, not tarpitting/delay. The UI section is literally
# called "Intrusion Prevention" and that's what these keys represent here.

collector_run() {

    # General
    collector_set "security.intrusion.process_smtp" "$(iw_get "C_Mail_Security_Tarpit_EnableSMTP" "" "" "")"
    collector_set "security.intrusion.process_pop3_imap" "$(iw_get "C_Mail_Security_Tarpit_EnableIMAPPOP3" "" "" "")"

    collector_set "security.intrusion.block_connections_per_minute.enabled" "$(iw_get "C_Mail_Security_Tarpit_BlockIP" "" "" "")"
    collector_set "security.intrusion.block_connections_per_minute.value" "$(iw_get "C_Mail_Security_Tarpit_BlockIPValue" "" "" "")"

    collector_set "security.intrusion.block_failed_logins.enabled" "$(iw_get "C_Mail_Security_Tarpit_Login" "" "" "")"
    collector_set "security.intrusion.block_failed_logins.value" "$(iw_get "C_Mail_Security_Tarpit_LoginCount" "" "" "")"

    # SMTP Specific Rules
    collector_set "security.intrusion.block_unknown_user_count.enabled" "$(iw_get "C_Mail_Security_Tarpit_Recipient" "" "" "")"
    collector_set "security.intrusion.block_unknown_user_count.value" "$(iw_get "C_Mail_Security_Tarpit_RecipientCount" "" "" "")"

    collector_set "security.intrusion.block_relay_denied_count.enabled" "$(iw_get "C_Mail_Security_Tarpit_RelayTarpit" "" "" "")"
    collector_set "security.intrusion.block_relay_denied_count.value" "$(iw_get "C_Mail_Security_Tarpit_RelayTarpitCount" "" "" "")"

    collector_set "security.intrusion.block_rset_count.enabled" "$(iw_get "C_Mail_Security_Tarpit_RSET" "" "" "")"
    collector_set "security.intrusion.block_rset_count.value" "$(iw_get "C_Mail_Security_Tarpit_RSETCount" "" "" "")"

    collector_set "security.intrusion.block_spam_score.enabled" "$(iw_get "C_Mail_Security_Tarpit_Spam" "" "" "")"
    collector_set "security.intrusion.block_spam_score.value" "$(iw_get "C_Mail_Security_Tarpit_SpamScore" "" "" "")"

    collector_set "security.intrusion.block_dnsbl_listed.enabled" "$(iw_get "C_Mail_Security_Tarpit_DNSBL" "" "" "")"

    collector_set "security.intrusion.block_message_size.enabled" "$(iw_get "C_Mail_Security_Tarpit_Msg_Enabled" "" "" "")"
    collector_set "security.intrusion.block_message_size.value_mb" "$(iw_get "C_Mail_Security_Tarpit_Msg_Value" "" "" "")"

    # Action
    collector_set "security.intrusion.block_duration_minutes" "$(iw_get "C_Mail_Security_Tarpit_Period" "" "" "")"
    collector_set "security.intrusion.close_blocked_connection" "$(iw_get "C_Mail_Security_Tarpit_CloseConnection" "" "" "")"
    collector_set "security.intrusion.close_all_other_connections" "$(iw_get "C_Mail_Security_Tarpit_CloseAllConnections" "" "" "")"
    collector_set "security.intrusion.cross_session_processing" "$(iw_get "C_Mail_Security_Tarpit_CrossSession" "" "" "")"

    # "Refuse blocked IP address" - NOT separately documented in the available
    # tool.help subset. Best candidate is the master tarpitting enable flag
    # below; please verify this against the live checkbox state on a test
    # server before trusting it.
    collector_set "security.intrusion.refuse_blocked_ip" "$(iw_get "C_Mail_Security_Tarpit_Enable" "" "" "")"
    collector_set "security.intrusion.refuse_blocked_ip_source" "UNVERIFIED:C_Mail_Security_Tarpit_Enable"

}
