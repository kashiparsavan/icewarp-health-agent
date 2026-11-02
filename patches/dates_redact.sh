#!/bin/bash
# --- add to lib/common.sh (single copy; delete the _days_ago copies in health.sh, pdf.sh, management_report.sh) ---

# norm_date <string>  -> prints YYYY-MM-DD, returns 1 if unparseable/empty.
# Accepts: 2026-10-28[ 02:01:18]  |  9-8-26 (IceWarp Linux, D-M-YY)  |
#          10/25/2026 (Windows, M/D/YYYY; D/M/YYYY if first field > 12)
norm_date() {
    local s="$1" y m d a b
    s="${s//\"/}"
    s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"
    [ -z "$s" ] && return 1
    if [[ "$s" =~ ^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})([ T].*)?$ ]]; then
        y=${BASH_REMATCH[1]} m=${BASH_REMATCH[2]} d=${BASH_REMATCH[3]}
    elif [[ "$s" =~ ^([0-9]{1,2})-([0-9]{1,2})-([0-9]{2}|[0-9]{4})$ ]]; then
        d=${BASH_REMATCH[1]} m=${BASH_REMATCH[2]} y=${BASH_REMATCH[3]}
    elif [[ "$s" =~ ^([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$ ]]; then
        a=${BASH_REMATCH[1]} b=${BASH_REMATCH[2]} y=${BASH_REMATCH[3]}
        if (( 10#$a > 12 )); then d=$a m=$b; else m=$a d=$b; fi
    else
        return 1
    fi
    (( 10#$y < 100 )) && y=$(( 2000 + 10#$y ))
    (( 10#$m >= 1 && 10#$m <= 12 && 10#$d >= 1 && 10#$d <= 31 )) || return 1
    printf '%04d-%02d-%02d' "$((10#$y))" "$((10#$m))" "$((10#$d))"
}

# _days_ago <string> -> prints whole days (>=0 or negative if future); prints nothing + returns 1 if unknown.
_days_ago() {
    local iso e
    iso="$(norm_date "$1")" || return 1
    e="$(date -d "$iso" +%s 2>/dev/null)" || return 1
    echo $(( ( $(date +%s) - e ) / 86400 ))
}

# redact_dsn <dsn> -> IceWarp DSN "db;user;password;host;type;flag" with field 3 masked.
redact_dsn() {
    printf '%s' "$1" | awk -F';' 'BEGIN{OFS=";"} { if ($3 != "") $3 = "***"; print }'
}
