#!/bin/bash

###############################################################################
#
# JSON Builder
#
###############################################################################

build_json() {

    {

        echo "{"

        FIRST=1

        for KEY in $(printf '%s\n' "${!DATA[@]}" | sort)
        do

            VALUE="${DATA[$KEY]}"

            VALUE="${VALUE//\\/\\\\}"
            VALUE="${VALUE//\"/\\\"}"

            if [ $FIRST -eq 0 ]
            then
                echo ","
            fi

            printf '  "%s":"%s"' "$KEY" "$VALUE"

            FIRST=0

        done

        echo
        echo "}"

    } > "$OUTPUT_JSON"

}
