#!/bin/bash

# Checklist: "Password Policy", "2FA",
#   "Block IP Address that Exceeds Number of Failed Login Attempts: ______"
#
# NOTE on 2FA: tool.help only exposes 2FA at the domain/account level
# (D_2F_Enabled, U_2F_ENABLED) and a global bypass list
# (C_Accounts_Policies_Login_Bypass_2f). There is no single global
# "2FA enabled server-wide" switch, so this collector reports the closest
# global signal (bypass list usage) and flags per-domain 2FA as TBD - needs
# iterating domains via tool.sh if a global rollup is required.

collector_run() {

    collector_set "security.login.policy_enabled" "$(iw_get "C_Accounts_Policies_Login_Enable" "" "" "")"
    collector_set "security.login.max_failed_attempts" "$(iw_get "C_Accounts_Policies_Login_Attempts" "" "" "")"
    collector_set "security.login.block_period_minutes" "$(iw_get "C_Accounts_Policies_Login_BlockPeriod" "" "" "")"
    collector_set "security.login.2fa_bypass_enabled" "$(iw_get "C_Accounts_Policies_Login_Bypass_2f" "" "" "")"

}
