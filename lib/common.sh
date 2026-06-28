#!/bin/bash

###############################################################################
#
# Common Library
#
###############################################################################

declare -Ag DATA

agent_init() {

    DATA=()

    DATA["agent.version"]="${AGENT_VERSION}"
    DATA["agent.hostname"]="$(hostname -f 2>/dev/null || hostname)"
    DATA["agent.time"]="$(date '+%F %T')"

}

collector_set() {

    local KEY="$1"
    local VALUE="${2:-}"

    DATA["$KEY"]="$VALUE"

}

list_collectors() {

    find "$COLLECTOR_DIR" -type f -name "*.sh" | \
        sed "s#${COLLECTOR_DIR}/##" | \
        sed 's#\.sh$##' | \
        sort

}

print_report() {

    echo
    echo "========================================"
    echo "IceWarp Health Check Report"
    echo "========================================"
    echo

    for KEY in $(printf "%s\n" "${!DATA[@]}" | sort)
    do
        printf "%-40s : %s\n" "$KEY" "${DATA[$KEY]}"
    done

    echo
    echo "Total Keys : ${#DATA[@]}"
    echo

}
