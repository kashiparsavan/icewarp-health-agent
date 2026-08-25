#!/bin/bash

# Checklist: "Enable Full Text Search Services"
# Property verified in tool.help: C_System_Services_Fulltext_Enabled
# (confirmed live via `tool.sh get system C_System_Services_Fulltext_Enabled`)
#
# Previously this key was set from C_System_Services_Fulltext_Scanner_URL
# in collectors/mailserver/smtp_limits.sh - the scanner's URL endpoint,
# which can be present/listening regardless of whether the feature is
# actually toggled on. That produced false "active" readings. This is the
# real enable/disable toggle.

collector_run() {
    local VALUE
    VALUE="$(iw_get "C_System_Services_Fulltext_Enabled" "" "" "")"
    collector_set "fulltext.enabled" "$VALUE"
}
