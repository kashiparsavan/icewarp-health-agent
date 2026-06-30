#!/bin/bash

###############################################################################
#
# JSON Builder
#
# Flat dotted-key JSON, but now type-aware: numeric and boolean-looking values
# are emitted unquoted so the monitoring server can parse them natively
# instead of everything arriving as a string.
#
###############################################################################

_json_escape() {

    local S="$1"

    S="${S//\\/\\\\}"
    S="${S//\"/\\\"}"
    S="${S//$'\t'/\\t}"
    S="${S//$'\r'/}"
    S="${S//$'\n'/\\n}"

    printf '%s' "$S"

}

_json_is_number() {
    [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]
}

_json_is_bool() {
    [[ "$1" == "true" || "$1" == "false" ]]
}

build_json() {

    {

        echo "{"

        local FIRST=1

        for KEY in $(printf '%s\n' "${!DATA[@]}" | sort)
        do

            local VALUE="${DATA[$KEY]}"

            if [ $FIRST -eq 0 ]
            then
                echo ","
            fi

            if [ -z "$VALUE" ]
            then
                printf '  "%s":null' "$KEY"
            elif _json_is_number "$VALUE"
            then
                printf '  "%s":%s' "$KEY" "$VALUE"
            elif _json_is_bool "$VALUE"
            then
                printf '  "%s":%s' "$KEY" "$VALUE"
            else
                printf '  "%s":"%s"' "$KEY" "$(_json_escape "$VALUE")"
            fi

            FIRST=0

        done

        echo
        echo "}"

    } > "$OUTPUT_JSON"

}
