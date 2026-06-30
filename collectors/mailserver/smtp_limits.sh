#!/bin/bash

# New fields confirmed against Mail > General > Advanced tab screenshot.
# These are not directly named in the printed checklist text, but appear in
# the same screen as several checklist items we already cover, and are
# useful supporting context for "SMTP / Message Processing" review.

collector_run() {

    collector_set "smtp.max_hop_count" "$(iw_get "C_Mail_SMTP_Other_MaxHopCount" "" "" "")"
    collector_set "smtp.max_server_recipients" "$(iw_get "C_Mail_SMTP_Other_MaxRecipients" "" "" "")"
    collector_set "smtp.max_client_recipients" "$(iw_get "C_Mail_SMTP_Other_MaxMTARecipients" "" "" "")"

    collector_set "smtp.max_per_domain_outgoing.enabled" "$(iw_get "C_System_Services_SMTP_MaxOutgoingLimitPerDomainEnabled" "" "" "")"
    collector_set "smtp.max_per_domain_outgoing.value" "$(iw_get "C_System_Services_SMTP_MaxOutgoingLimitPerDomainValue" "" "" "")"

    collector_set "smtp.max_per_domain_sender.enabled" "$(iw_get "C_System_Services_SMTP_MaxSenderLimitPerDomainEnabled" "" "" "")"
    collector_set "smtp.max_per_domain_sender.value" "$(iw_get "C_System_Services_SMTP_MaxSenderLimitPerDomainValue" "" "" "")"

    collector_set "smtp.enforce_tls_secondary_port" "$(iw_get "C_Mail_SMTP_Delivery_EnforceTlsOnSecondarySmtpPort" "" "" "")"
    collector_set "smtp.header_footer_active" "$(iw_get "C_Mail_SMTP_HeaderFooter_Enable" "" "" "")"
    collector_set "fulltext.enabled" "$(iw_get "C_System_Services_Fulltext_Scanner_URL" "" "" "")"

}
