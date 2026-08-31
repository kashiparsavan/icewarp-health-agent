#!/bin/bash
# collectors/dns/resolver_external.sh
# Checks external DNS resolution for multiple domains

collector_run() {
    local DOMAINS=("google.com" "icewarp.com" "parsavan.com")

    for DOMAIN in "${DOMAINS[@]}"; do
        local KEY="dns.resolver.external_test_ok_${DOMAIN//./_}"
        if timeout 5 dig +short "$DOMAIN" >/dev/null 2>&1; then
            DATA["$KEY"]="true"
        else
            DATA["$KEY"]="false"
        fi
    done
}
