#!/bin/bash
# collectors/security/dnsbl_zones.sh
# Check configured DNSBL zones and validate against recommended list

collector_run() {
    local DNSBL_ZONES
    local ZONE_COUNT=0

    if [ -n "${IW_TOOL:-}" ] && [ -x "$IW_TOOL" ]; then
        # Get configured DNSBL zones from tool.sh
        # Try multiple possible keys
        DNSBL_ZONES="$(timeout 5 "$IW_TOOL" display system C_Mail_Security_DNSBL_Hosts 2>/dev/null | awk -F': ' '{print $2}')"
        
        # Fallback: try alternative key names
        if [ -z "$DNSBL_ZONES" ]; then
            DNSBL_ZONES="$(timeout 5 "$IW_TOOL" display system C_Mail_Security_Protection_DNSBLZones 2>/dev/null | awk -F': ' '{print $2}')"
        fi
        
        # Another fallback
        if [ -z "$DNSBL_ZONES" ]; then
            DNSBL_ZONES="$(timeout 5 "$IW_TOOL" display system C_Mail_Security_AntiSpam_DNSBLZones 2>/dev/null | awk -F': ' '{print $2}')"
        fi
        
        # Another fallback
        if [ -z "$DNSBL_ZONES" ]; then
            DNSBL_ZONES="$(timeout 5 "$IW_TOOL" display system C_Security_DNSBL_Zones 2>/dev/null | awk -F': ' '{print $2}')"
        fi
    fi

    # Fallback: check XML config for DNSBL zones
    if [ -z "$DNSBL_ZONES" ] && [ -f /opt/icewarp-data/config/license.xml ]; then
        DNSBL_ZONES="$(grep -ioP '<DNSBL[^>]*>\K[^<]+' /opt/icewarp-data/config/license.xml 2>/dev/null | head -n1)"
    fi
    if [ -z "$DNSBL_ZONES" ] && [ -f /opt/icewarp/config/license.xml ]; then
        DNSBL_ZONES="$(grep -ioP '<DNSBL[^>]*>\K[^<]+' /opt/icewarp/config/license.xml 2>/dev/null | head -n1)"
    fi

    # Normalize the zones list
    if [ -n "$DNSBL_ZONES" ]; then
        # Clean up the zones list - remove extra spaces, normalize separators
        DNSBL_ZONES=$(echo "$DNSBL_ZONES" | tr -d ' ' | tr ';' ',' | tr '|' ',')
        ZONE_COUNT=$(echo "$DNSBL_ZONES" | grep -o ',' | wc -l)
        ZONE_COUNT=$((ZONE_COUNT + 1))
    else
        DNSBL_ZONES=""
    fi

    collector_set "security.dnsbl.zones" "$DNSBL_ZONES"
    collector_set "security.dnsbl.zones.count" "$ZONE_COUNT"
}