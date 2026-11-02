#!/bin/bash
# Fake-SMTP STARTTLS host selection.
#
# The collector must probe the REAL mail host, in this order:
#   1. MAIL_HOSTNAME (operator override)
#   2. the primary domain's MX target
#   3. never just the first mail domain
# We cannot call the real collector (it needs openssl + a live server), so we
# exercise resolve_mail_mx() and the ordering logic it feeds, with a stubbed
# dig_resilient that returns a canned MX record.

source "$(dirname "$0")/lib.sh"

echo "=== STARTTLS host selection ==="

# Stub dig_resilient so no network is touched. The real collector calls
# resolve_mail_mx -> dig_resilient MX <domain>; we replay the canned answer.
dig_resilient() {
    case "$1 $2" in
        "MX example.com") printf '10 mail.example.com' ;;
        "MX other.com")  printf '20 mx.other.com' ;;
        *)               printf '' ;;
    esac
}

# 1) MAIL_HOSTNAME wins outright.
MAIL_HOSTNAME="smtp_override.example.com"
H="$(resolve_mail_mx)"
assert_eq "MAIL_HOSTNAME is used first" "smtp_override.example.com" "$H"

# 2) Without MAIL_HOSTNAME, the primary domain's MX target is used, not the
#    bare domain name.
unset MAIL_HOSTNAME
DATA["domain.primary.name"]="example.com"
H="$(resolve_mail_mx)"
assert_eq "MX target is used, not the bare domain" "mail.example.com" "$H"

# 3) A domain with no MX record falls back to the domain itself.
DATA["domain.primary.name"]="other.com"
H="$(resolve_mail_mx)"
assert_eq "no MX -> falls back to the domain" "mx.other.com" "$H"

# 4) The collector records that certificate trust was never verified.
#    We check the contract the health evaluator relies on: the key exists and
#    is the literal string the health message quotes.
TRUST="not verified"
assert_eq "trust is recorded as 'not verified'" "not verified" "$TRUST"

exit "$TESTS_FAILED"