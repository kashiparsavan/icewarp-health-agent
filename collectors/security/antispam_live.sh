#!/bin/bash

# Checklist: "Disable AntiSpam Live"
# Source: C_AS_Live_Enable (confirmed in tool.help, alias of the older
# C_AS_CommTouch property). True = Anti-Spam Live is enabled, which is the
# opposite of what "Disable AntiSpam Live" wants.

collector_run() {
    collector_set "security.antispam_live.enabled" "$(iw_get "C_AS_Live_Enable" "" "" "")"
}
