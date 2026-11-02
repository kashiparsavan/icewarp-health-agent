#!/bin/bash
# _json_value / _json_force_string: the type-aware coercion rules in
# lib/json.sh (CLAUDE.md 3.8). Numbers stay unquoted, booleans stay unquoted,
# empty becomes null, and identifier keys are always strings.

source "$(dirname "$0")/lib.sh"

echo "=== _json_value ==="

# Numbers and booleans
assert_eq "integer" "42" "$(_json_value "os.cpu.count" "42")"
assert_eq "float" "9.00" "$(_json_value "intrusion.spam_score" "9.00")"
assert_eq "negative" "-3" "$(_json_value "x" "-3")"
assert_eq "boolean true" "true" "$(_json_value "x" "true")"
assert_eq "boolean false" "false" "$(_json_value "x" "false")"

# Empty and the literal null -> null
assert_eq "empty -> null" "null" "$(_json_value "x" "")"
assert_eq "literal null -> null" "null" "$(_json_value "x" "null")"

# Strings are escaped
assert_eq "plain string" '"hello"' "$(_json_value "x" "hello")"
assert_eq "quotes escaped" '"a\"b"' "$(_json_value "x" 'a"b')"
assert_eq "backslash escaped" '"a\\b"' "$(_json_value "x" 'a\b')"

# Identifier keys are forced to strings even when they look numeric.
# "9.10" must stay a string, not become 9.1.
assert_eq "version forced string" '"9.10"' "$(_json_value "icewarp.version" "9.10")"
assert_eq "ip forced string" '"10.0.0.5"' "$(_json_value "agent.hostname" "10.0.0.5")"
assert_eq "domain forced string" '"example.com"' "$(_json_value "domain.primary.name" "example.com")"
assert_eq "hostname forced string" '"mail01.example.com"' "$(_json_value "agent.hostname" "mail01.example.com")"

# New: company / technician / name keys must never be coerced to a number.
assert_eq "company forced string" '"Example Corp"' "$(_json_value "general.company" "Example Corp")"
assert_eq "technician forced string" '"Jane Doe"' "$(_json_value "general.technician" "Jane Doe")"
assert_eq "name forced string" '"example.com"' "$(_json_value "domain.primary.name" "example.com")"

# A numeric-looking company name must still be a string.
assert_eq "numeric company stays string" '"42"' "$(_json_value "general.company" "42")"

# License identifiers are free text, not quantities.
assert_eq "license type forced string" '"Evaluation"' "$(_json_value "icewarp.license.type" "Evaluation")"
assert_eq "license status forced string" '"installed"' "$(_json_value "icewarp.license.status" "installed")"
assert_eq "license seats note forced string" '"not available via tool.sh - use API or database query"' \
    "$(_json_value "icewarp.license.used_seats_note" "not available via tool.sh - use API or database query")"

# A 0/1 flag is NOT an identifier: it must stay a number.
assert_eq "flag stays numeric" "1" "$(_json_value "smtp.hide_server_version" "1")"

exit "$TESTS_FAILED"