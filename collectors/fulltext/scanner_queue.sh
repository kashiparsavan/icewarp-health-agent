#!/bin/bash

# Property verified in tool.help: C_System_Services_Fulltext_Scanner_Queues
# (Read only - contents of fulltext search scanner service queues)

collector_run() {

    local VALUE
    VALUE="$(iw_get "C_System_Services_Fulltext_Scanner_Queues" "" "" "")"

    collector_set "fulltext.scanner.queues" "$VALUE"

}
