#!/bin/bash

# Adds the "Login policy mode" dropdown (matches Policies > Login Policy)
# that was missing from the original security/login_policy.sh.
# C_Accounts_Policies_Login_Block values: 0=delay, 1=block for time,
# 2=block for time (strict)

collector_run() {

    collector_set "security.login.block_mode" "$(iw_get "C_Accounts_Policies_Login_Block" "" "" "")"

}
