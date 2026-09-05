#!/bin/bash

# Checklist: "Daily Send Email limit: ______"
#
# REWRITTEN per explicit requirement: this must work unmodified across
# hundreds of production servers, so the domain is no longer a manually
# configured value. Real domains are auto-discovered via `tool list domain`
# (iw_list_domains() in common.sh), with the internal service domain
# ("##internalservicedomain.icewarp.com##") filtered out automatically.
#
# This is intentionally scoped to ONLY the genuinely domain-level checklist
# items (Daily Send Limit, Disk Quota, etc). Most checklist items are global
# server settings and must NOT be looped per domain - that would be wasted
# work and misleading duplication for items that apply identically to every
# domain on the box.

collector_run() {

    local DOMAINS
    local COUNT=0
    local KEY_SAFE

    DOMAINS="$(iw_list_domains)"

    if [ -z "$DOMAINS" ]; then
        collector_set "domain.checked" "false"
        collector_set "domain.reason" "no domains returned by 'tool list domain' (or tool.sh unavailable)"
        collector_set "domain.count" "0"
        return
    fi

    collector_set "domain.checked" "true"

    while IFS= read -r DOMAIN
    do
        [ -z "$DOMAIN" ] && continue
        COUNT=$((COUNT + 1))

        KEY_SAFE="$(echo "$DOMAIN" | tr -d ' \t')"

        collector_set "domain.${KEY_SAFE}.daily_send_messages_limit" "$(iw_get_domain "$DOMAIN" "D_NumberLimit" "" "" "")"
        collector_set "domain.${KEY_SAFE}.disk_quota_kb" "$(iw_get_domain "$DOMAIN" "D_DiskQuota" "" "" "")"
        collector_set "domain.${KEY_SAFE}.user_send_data_limit_mb_per_day" "$(iw_get_domain "$DOMAIN" "D_UserMB" "" "" "")"

        # Fixed alias for the first domain seen, since the checklist report
        # needs one stable key to point at regardless of the real domain
        # name (which varies per install).
        if [ "$COUNT" -eq 1 ]; then
            collector_set "domain.primary.name" "$DOMAIN"
            collector_set "domain.primary.daily_send_messages_limit" "${DATA[domain.${KEY_SAFE}.daily_send_messages_limit]:-}"
        fi

    done <<< "$DOMAINS"

    collector_set "domain.count" "$COUNT"
    collector_set "domain.list" "$(echo "$DOMAINS" | tr '\n' ';')"

}
