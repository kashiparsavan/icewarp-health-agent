#!/bin/bash

# Checklist: "Disable Cloud Features"
# Source: C_CloudAPI_AutoConfigure (confirmed in tool.help) - "Auto
# configure Cloud API using MSR service". True = cloud auto-config active,
# which is the opposite of what "Disable Cloud Features" wants.

collector_run() {
    collector_set "icewarp.cloud_api.autoconfigure" "$(iw_get "C_CloudAPI_AutoConfigure" "" "" "")"
}
