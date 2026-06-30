#!/bin/bash

collector_run() {

    local VERSION
    VERSION="$(iw_get "C_Version" "" "" "")"

    collector_set "icewarp.version" "$VERSION"

}
