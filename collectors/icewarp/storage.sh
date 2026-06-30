#!/bin/bash

collector_run() {

    collector_set "icewarp.path.mail" "/opt/icewarp/mail"
    collector_set "icewarp.path.archive" "/opt/icewarp/archive"
    collector_set "icewarp.path.logs" "/opt/icewarp/logs"
    collector_set "icewarp.path.temp" "/opt/icewarp/temp"
    collector_set "icewarp.path.backup" "/opt/icewarp/backup"

}
