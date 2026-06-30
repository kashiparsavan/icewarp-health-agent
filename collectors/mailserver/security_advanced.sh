#!/bin/bash

# Checklist items resolved here (matches Mail > Security > Advanced tab):
#   "Require HELO/EHLO"   -> C_Mail_Security_Protection_HELOEHLO (was ❌, now found)
#   Greeting delay         -> C_Mail_Security_Protection_SMTPWait
#   Global POP before SMTP -> C_Mail_Security_Relay_POPSMTPGlobal

collector_run() {

    collector_set "smtp.require_helo_ehlo" "$(iw_get "C_Mail_Security_Protection_HELOEHLO" "" "" "")"
    collector_set "smtp.greeting_delay_seconds" "$(iw_get "C_Mail_Security_Protection_SMTPWait" "" "" "")"
    collector_set "smtp.global_pop_before_smtp" "$(iw_get "C_Mail_Security_Relay_POPSMTPGlobal" "" "" "")"

}
