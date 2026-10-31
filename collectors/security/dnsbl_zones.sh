#!/bin/bash
# collectors/security/dnsbl_zones.sh
#
# The DNSBL server list is NOT exposed by any tool.sh property (it is absent
# from APIConst), so the previous guessed C_* keys always returned nothing and
# the check reported "No DNSBL zones configured" on correctly configured
# servers. IceWarp keeps the list in its config files, so scan those for
# well-known DNSBL zones. Name-matching files (dnsbl/rbl/blacklist/dns) are
# tried first, then other top-level config files (spam/rule files excluded).
#
# security.dnsbl.zones.source records the file that answered, or "not_found"
# when no config file could be read - health.sh uses that to say "could not be
# read" instead of the false "no zones configured".

_DNSBL_KNOWN='zen\.spamhaus\.org|sbl-xbl\.spamhaus\.org|sbl\.spamhaus\.org|xbl\.spamhaus\.org|pbl\.spamhaus\.org|bl\.spamcop\.net|b\.barracudacentral\.org|dnsbl\.sorbs\.net|cbl\.abuseat\.org|psbl\.surriel\.com|bl\.mailspike\.net|dnsbl\.dronebl\.org|ix\.dnsbl\.manitu\.net|dnsbl-[0-9]\.uceprotect\.net'

_dnsbl_scan_file() {
    grep -ohiE "$_DNSBL_KNOWN" "$1" 2>/dev/null | tr 'A-Z' 'a-z' | sort -u | paste -sd',' -
}

collector_run() {
    local ZONES="" SOURCE="not_found" ZONE_COUNT=0 D F
    local -a DIRS=("${IW_CONFIG:-}" /opt/icewarp-data/config /opt/icewarp/config)

    for D in "${DIRS[@]}"; do
        [ -n "$D" ] && [ -d "$D" ] || continue
        # pass 1: obviously named files; pass 2: remaining top-level config files
        while IFS= read -r F; do
            ZONES="$(_dnsbl_scan_file "$F")"
            if [ -n "$ZONES" ]; then SOURCE="$(basename "$F")"; break; fi
            [ "$SOURCE" = "not_found" ] && SOURCE="scanned_no_match"
        done < <(find "$D" -maxdepth 1 -type f -size -2048k \
                    \( -iname '*dnsbl*' -o -iname '*rbl*' -o -iname '*blacklist*' -o -iname '*dns*' \) 2>/dev/null | sort)
        if [ -z "$ZONES" ]; then
            while IFS= read -r F; do
                ZONES="$(_dnsbl_scan_file "$F")"
                if [ -n "$ZONES" ]; then SOURCE="$(basename "$F")"; break; fi
                [ "$SOURCE" = "not_found" ] && SOURCE="scanned_no_match"
            done < <(find "$D" -maxdepth 1 -type f -size -2048k \( -iname '*.cfg' -o -iname '*.xml' -o -iname '*.dat' -o -iname '*.conf' \) \
                        ! -iname '*spam*' ! -iname '*rule*' 2>/dev/null | sort)
        fi
        [ -n "$ZONES" ] && break
    done

    [ -n "$ZONES" ] && ZONE_COUNT="$(printf '%s' "$ZONES" | tr ',' '\n' | grep -c .)"

    collector_set "security.dnsbl.zones" "$ZONES"
    collector_set "security.dnsbl.zones.count" "$ZONE_COUNT"
    collector_set "security.dnsbl.zones.source" "$SOURCE"
}
