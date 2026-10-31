#!/bin/bash

###############################################################################
#
# JSON Builder
#
# Flat dotted-key JSON, type-aware (rules in CLAUDE.md 3.8):
#   empty or the literal "null"      -> null
#   strict JSON number               -> unquoted number (no leading zeros, max 15 digits)
#   true / false                     -> unquoted boolean
#   keys in _json_force_string       -> always a string (versions, IPs ...)
#   everything else                  -> escaped string
#
###############################################################################

_json_escape() {

    local S="$1"

    S="${S//\\/\\\\}"
    S="${S//\"/\\\"}"
    S="${S//$'\t'/\\t}"
    S="${S//$'\r'/}"
    S="${S//$'\n'/\\n}"
    S="${S//[[:cntrl:]]/}"

    printf '%s' "$S"

}

# Strict RFC 8259 number: "007" and "00123" are NOT numbers, 15-digit cap keeps
# the value exactly representable in a double.
_json_is_number() {
    [[ "$1" =~ ^-?(0|[1-9][0-9]{0,14})(\.[0-9]{1,6})?$ ]]
}

_json_is_bool() {
    [[ "$1" == "true" || "$1" == "false" ]]
}

# Keys whose value is an identifier, not a quantity: "9.10" must not become 9.1.
_json_force_string() {
    case "$1" in
        *version|*version_raw|*.ip|*.checked_ip|*.domain|*.hostname|*.host) return 0 ;;
    esac
    return 1
}

# _json_value <key> <value>  -> prints the JSON token for the value
_json_value() {
    local KEY="$1" VALUE="$2"

    case "$KEY" in
        *dsn*|*connection_string*) VALUE="$(redact_dsn "$VALUE")" ;;
    esac

    if [ -z "$VALUE" ] || [ "$VALUE" = "null" ]; then
        printf 'null'
    elif _json_force_string "$KEY"; then
        printf '"%s"' "$(_json_escape "$VALUE")"
    elif _json_is_number "$VALUE" || _json_is_bool "$VALUE"; then
        printf '%s' "$VALUE"
    else
        printf '"%s"' "$(_json_escape "$VALUE")"
    fi
}

build_json() {

    {

        echo "{"

        local FIRST=1
        local KEY

        for KEY in $(printf '%s\n' "${!DATA[@]}" | sort)
        do

            if [ $FIRST -eq 0 ]
            then
                echo ","
            fi

            printf '  "%s":%s' "$(_json_escape "$KEY")" "$(_json_value "$KEY" "${DATA[$KEY]}")"

            FIRST=0

        done

        echo
        echo "}"

    } > "$OUTPUT_JSON"

}
