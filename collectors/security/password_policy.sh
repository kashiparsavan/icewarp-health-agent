#!/bin/bash

# Checklist: "Password Policy" - verified against Policies > Password Policy

collector_run() {

    collector_set "security.password_policy.active" "$(iw_get "C_Accounts_Policies_Pass_Enable" "" "" "")"
    collector_set "security.password_policy.no_username_in_password" "$(iw_get "C_Accounts_Policies_Pass_UserAlias" "" "" "")"
    collector_set "security.password_policy.min_length" "$(iw_get "C_Accounts_Policies_Pass_MinLength" "" "" "")"
    collector_set "security.password_policy.min_digits" "$(iw_get "C_Accounts_Policies_Pass_Digits" "" "" "")"
    collector_set "security.password_policy.min_non_alphanumeric" "$(iw_get "C_Accounts_Policies_Pass_NonAlphaNum" "" "" "")"
    collector_set "security.password_policy.min_alpha" "$(iw_get "C_Accounts_Policies_Pass_Alpha" "" "" "")"
    collector_set "security.password_policy.min_uppercase" "$(iw_get "C_Accounts_Policies_Pass_UpperAlpha" "" "" "")"

    collector_set "security.password_policy.expiration_active" "$(iw_get "C_Accounts_Policies_Pass_Expiration" "" "" "")"
    collector_set "security.password_policy.expire_after_days" "$(iw_get "C_Accounts_Policies_Pass_ExpireAfter" "" "" "")"
    collector_set "security.password_policy.notify_before_days" "$(iw_get "C_Accounts_Policies_Pass_NotifyBefore" "" "" "")"
    collector_set "security.password_policy.disable_access_when_expired" "$(iw_get "C_Accounts_Policies_Pass_DisableAccessToAllIfDisabled" "" "" "")"

}
