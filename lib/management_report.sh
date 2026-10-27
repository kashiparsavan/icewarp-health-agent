#!/bin/bash

###############################################################################
# =============================================================================
# SECTION 1: HEADER AND LICENSE
# =============================================================================
#
# Management Report (lib/management_report.sh)
#
# A short, non-technical report for management/customers: a cover letter
# page plus 2-3 condensed summary pages - no raw data, no per-item notes,
# just a status grid grouped by checklist section.
# Reads from config/checklist.conf.pdf - same source as the full technical report.
#
###############################################################################

# =============================================================================
# SECTION 2: CONSTANTS (Page dimensions, colors, margins)
# =============================================================================

MR_PAGE_W=612
MR_PAGE_H=792
MR_MARGIN=44
MR_TOP_Y=744
MR_BOTTOM_Y=52
MR_RIGHT=$((MR_PAGE_W - MR_MARGIN))
MR_CONTENT_W=$((MR_RIGHT - MR_MARGIN))

# "Soft cyberpunk" palette: deep ink surfaces, desaturated teal and violet
# accents, and restrained status colours. All text pairings target WCAG AA
# contrast on their respective backgrounds.
MR_C_INK="0.043 0.063 0.102"
MR_C_INK_2="0.075 0.102 0.153"
MR_C_NAVY="0.075 0.118 0.196"
MR_C_GRID="0.105 0.145 0.205"
MR_C_SURFACE="0.965 0.973 0.984"
MR_C_CARD="1 1 1"
MR_C_BORDER="0.855 0.890 0.930"
MR_C_TEXT="0.090 0.120 0.170"
MR_C_MUTED="0.360 0.410 0.480"
MR_C_TEAL="0.160 0.700 0.640"
MR_C_TEAL_DARK="0.055 0.470 0.430"
MR_C_TEAL_LIGHT="0.550 0.900 0.850"
MR_C_VIOLET="0.480 0.420 0.850"
MR_C_VIOLET_DARK="0.350 0.300 0.700"
MR_C_ROSE="0.830 0.280 0.380"
MR_C_ROSE_DARK="0.690 0.180 0.280"
MR_C_AMBER="0.900 0.630 0.200"
MR_C_AMBER_DARK="0.670 0.420 0.080"
MR_C_GREEN="0.100 0.550 0.440"
MR_C_GREEN_DARK="0.070 0.420 0.340"
MR_C_SLATE="0.400 0.460 0.550"
MR_C_WHITE="1 1 1"
MR_CHECKLIST_VERSION="${CHECKLIST_VERSION:-1.14}"

# =============================================================================
# SECTION 3: HELPER FUNCTIONS
# =============================================================================

_is_num() { [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; }

_mr_escape() {
    local S="$1"
    S="$(printf '%s' "$S" | LC_ALL=C tr -c '\40-\176' '?')"
    S="${S//\\/\\\\}"; S="${S//(/\\(}"; S="${S//)/\\)}"
    printf '%s' "$S"
}

_mr_rect() {
    _MR_CUR="${_MR_CUR}${5} rg
${1} ${2} ${3} ${4} re f
"
}

_mr_text() {
    local ESC; ESC="$(_mr_escape "$3")"
    _MR_CUR="${_MR_CUR}${6} rg
BT /${4} ${5} Tf ${1} ${2} Td (${ESC}) Tj ET
"
}

_mr_text_trunc() {
    local MAXC="$7" TXT="$3"
    if [ "${#TXT}" -gt "$MAXC" ]; then
        TXT="${TXT:0:$((MAXC-3))}"
        TXT="${TXT% }..."
    fi
    _mr_text "$1" "$2" "$TXT" "$4" "$5" "$6"
}

_mr_text_center() {
    local CX="$1" Y="$2" TXT="$3" FONT="$4" SIZE="$5" COLOR="$6"
    local W
    W="$(awk -v n="${#TXT}" -v s="$SIZE" 'BEGIN{printf "%.1f", n*s*0.52}')"
    _mr_text "$(awk -v c="$CX" -v w="$W" 'BEGIN{printf "%.1f", c-w/2}')" "$Y" "$TXT" "$FONT" "$SIZE" "$COLOR"
}

_mr_text_right() {
    local RX="$1" Y="$2" TXT="$3" FONT="$4" SIZE="$5" COLOR="$6"
    local W
    W="$(awk -v n="${#TXT}" -v s="$SIZE" 'BEGIN{printf "%.1f", n*s*0.52}')"
    _mr_text "$(awk -v r="$RX" -v w="$W" 'BEGIN{printf "%.1f", r-w}')" "$Y" "$TXT" "$FONT" "$SIZE" "$COLOR"
}

_mr_line() {
    local X1="$1" Y1="$2" X2="$3" Y2="$4" W="${5:-0.6}" COLOR="${6:-$MR_C_BORDER}"
    _MR_CUR="${_MR_CUR}${COLOR} RG
${W} w
${X1} ${Y1} m ${X2} ${Y2} l S
"
}

_mr_round_rect() {
    local X="$1" Y="$2" W="$3" H="$4" R="$5" COLOR="$6"
    local X2=$((X + W)) Y2=$((Y + H)) K=$((R * 55 / 100))
    [ "$K" -lt 1 ] && K=1
    _MR_CUR="${_MR_CUR}${COLOR} rg
$((X + R)) ${Y} m
$((X2 - R)) ${Y} l
$((X2 - R + K)) ${Y} $((X2)) $((Y + R - K)) ${X2} $((Y + R)) c
${X2} $((Y2 - R)) l
${X2} $((Y2 - R + K)) $((X2 - R + K)) ${Y2} $((X2 - R)) ${Y2} c
$((X + R)) ${Y2} l
$((X + R - K)) ${Y2} ${X} $((Y2 - R + K)) ${X} $((Y2 - R)) c
${X} $((Y + R)) l
${X} $((Y + R - K)) $((X + R - K)) ${Y} $((X + R)) ${Y} c
f
"
}

_mr_card() {
    local X="$1" Y="$2" W="$3" H="$4" R="${5:-6}"
    _mr_round_rect "$X" "$Y" "$W" "$H" "$R" "$MR_C_BORDER"
    _mr_round_rect "$((X + 1))" "$((Y + 1))" "$((W - 2))" "$((H - 2))" "$((R - 1))" "$MR_C_CARD"
}

_mr_dark_card() {
    local X="$1" Y="$2" W="$3" H="$4" R="${5:-6}"
    _mr_round_rect "$X" "$Y" "$W" "$H" "$R" "0.120 0.160 0.230"
    _mr_round_rect "$((X + 1))" "$((Y + 1))" "$((W - 2))" "$((H - 2))" "$((R - 1))" "$MR_C_INK_2"
}

_mr_ring() {
    local CX="$1" CY="$2" R="$3" WIDTH="$4" COLOR="$5"
    local K X0 X1 Y0 Y1
    K="$(awk -v r="$R" 'BEGIN{printf "%.3f", r*0.5523}')"
    X0="$(awk -v c="$CX" -v r="$R" 'BEGIN{printf "%.2f", c-r}')"
    X1="$(awk -v c="$CX" -v r="$R" 'BEGIN{printf "%.2f", c+r}')"
    Y0="$(awk -v c="$CY" -v r="$R" 'BEGIN{printf "%.2f", c-r}')"
    Y1="$(awk -v c="$CY" -v r="$R" 'BEGIN{printf "%.2f", c+r}')"
    _MR_CUR="${_MR_CUR}${COLOR} RG
${WIDTH} w
${CX} ${Y1} m
$(awk -v cx="$CX" -v k="$K" -v y1="$Y1" 'BEGIN{printf "%.2f %.2f", cx+k, y1}') $(awk -v x1="$X1" -v cy="$CY" -v k="$K" 'BEGIN{printf "%.2f %.2f", x1, cy+k}') ${X1} ${CY} c
$(awk -v x1="$X1" -v cy="$CY" -v k="$K" 'BEGIN{printf "%.2f %.2f", x1, cy-k}') $(awk -v cx="$CX" -v k="$K" -v y0="$Y0" 'BEGIN{printf "%.2f %.2f", cx+k, y0}') ${CX} ${Y0} c
$(awk -v cx="$CX" -v k="$K" -v y0="$Y0" 'BEGIN{printf "%.2f %.2f", cx-k, y0}') $(awk -v x0="$X0" -v cy="$CY" -v k="$K" 'BEGIN{printf "%.2f %.2f", x0, cy-k}') ${X0} ${CY} c
$(awk -v x0="$X0" -v cy="$CY" -v k="$K" 'BEGIN{printf "%.2f %.2f", x0, cy+k}') $(awk -v cx="$CX" -v k="$K" -v y1="$Y1" 'BEGIN{printf "%.2f %.2f", cx-k, y1}') ${CX} ${Y1} c
S
"
}

_mr_arc() {
    local CX="$1" CY="$2" R="$3" WIDTH="$4" COLOR="$5" PERCENT="$6"
    [ "${PERCENT:-0}" -le 0 ] && return
    local ARC
    ARC="$(awk -v cx="$CX" -v cy="$CY" -v r="$R" -v p="$PERCENT" 'BEGIN{
        n=72; pi=atan2(0,-1); a0=pi/2; sweep=-2*pi*p/100;
        for (i=0; i<=n; i++) {
            a=a0+sweep*i/n;
            x=cx+r*cos(a); y=cy+r*sin(a);
            if (i==0) printf "%.2f %.2f m\n", x, y;
            else printf "%.2f %.2f l\n", x, y;
        }
    }')"
    _MR_CUR="${_MR_CUR}${COLOR} RG
${WIDTH} w
${ARC}
S
"
}

_mr_paragraph() {
    local X="$1" Y="$2" TEXT="$3" MAXC="$4" FONT="$5" SIZE="$6" COLOR="$7" LEAD="${8:-13}" MAXLINES="${9:-0}"
    LEAD="${LEAD%%.*}"
    local -a WORDS=()
    read -ra WORDS <<< "$TEXT"
    local LINE="" CAND="" COUNT=0 W
    for W in "${WORDS[@]}"; do
        if [ -z "$LINE" ]; then
            CAND="$W"
        else
            CAND="${LINE} ${W}"
        fi
        if [ "${#CAND}" -le "$MAXC" ]; then
            LINE="$CAND"
        else
            _mr_text "$X" "$Y" "$LINE" "$FONT" "$SIZE" "$COLOR"
            Y=$((Y - LEAD))
            COUNT=$((COUNT + 1))
            if [ "$MAXLINES" -gt 0 ] && [ "$COUNT" -ge "$MAXLINES" ]; then
                _MR_LAST_Y=$Y
                return
            fi
            LINE="$W"
        fi
    done
    if [ -n "$LINE" ]; then
        _mr_text "$X" "$Y" "$LINE" "$FONT" "$SIZE" "$COLOR"
        Y=$((Y - LEAD))
    fi
    _MR_LAST_Y=$Y
}

_mr_status_color() {
    case "$1" in
        PASS|pass)          echo "$MR_C_TEAL" ;;
        WARN|warn)          echo "$MR_C_AMBER" ;;
        CRITICAL|FAIL|fail) echo "$MR_C_ROSE" ;;
        INFO|info)          echo "$MR_C_VIOLET" ;;
        *)                  echo "$MR_C_SLATE" ;;
    esac
}

_mr_status_fill() {
    case "$1" in
        PASS|pass)          echo "$MR_C_GREEN_DARK" ;;
        WARN|warn)          echo "$MR_C_AMBER" ;;
        CRITICAL|FAIL|fail) echo "$MR_C_ROSE_DARK" ;;
        INFO|info)          echo "$MR_C_VIOLET_DARK" ;;
        *)                  echo "$MR_C_SLATE" ;;
    esac
}

_mr_status_text_color() {
    case "$1" in
        WARN|warn) echo "$MR_C_INK" ;;
        *)         echo "$MR_C_WHITE" ;;
    esac
}

_mr_status_word() {
    case "$1" in
        PASS|pass)          echo "Healthy" ;;
        WARN|warn)          echo "Review" ;;
        CRITICAL|FAIL|fail) echo "Action" ;;
        INFO|info)          echo "Info" ;;
        *)                  echo "N/A" ;;
    esac
}

_mr_overall_word() {
    case "$1" in
        pass) echo "Healthy" ;;
        warn) echo "Needs review" ;;
        fail) echo "Action required" ;;
        *)    echo "Not assessed" ;;
    esac
}

_mr_circle() {
    local CX="$1" CY="$2" R="$3" COLOR="$4"
    local K
    K="$(awk -v r="$R" 'BEGIN{printf "%.3f", r*0.5523}')"
    local X0 X1 Y0 Y1
    X0="$(awk -v c="$CX" -v r="$R" 'BEGIN{printf "%.2f", c-r}')"
    X1="$(awk -v c="$CX" -v r="$R" 'BEGIN{printf "%.2f", c+r}')"
    Y0="$(awk -v c="$CY" -v r="$R" 'BEGIN{printf "%.2f", c-r}')"
    Y1="$(awk -v c="$CY" -v r="$R" 'BEGIN{printf "%.2f", c+r}')"
    _MR_CUR="${_MR_CUR}${COLOR} rg
${CX} ${Y1} m
$(awk -v cx="$CX" -v k="$K" -v y1="$Y1" 'BEGIN{printf "%.2f %.2f", cx+k, y1}') $(awk -v x1="$X1" -v cy="$CY" -v k="$K" 'BEGIN{printf "%.2f %.2f", x1, cy+k}') ${X1} ${CY} c
$(awk -v x1="$X1" -v cy="$CY" -v k="$K" 'BEGIN{printf "%.2f %.2f", x1, cy-k}') $(awk -v cx="$CX" -v k="$K" -v y0="$Y0" 'BEGIN{printf "%.2f %.2f", cx+k, y0}') ${CX} ${Y0} c
$(awk -v cx="$CX" -v k="$K" -v y0="$Y0" 'BEGIN{printf "%.2f %.2f", cx-k, y0}') $(awk -v x0="$X0" -v cy="$CY" -v k="$K" 'BEGIN{printf "%.2f %.2f", x0, cy-k}') ${X0} ${CY} c
$(awk -v x0="$X0" -v cy="$CY" -v k="$K" 'BEGIN{printf "%.2f %.2f", x0, cy+k}') $(awk -v cx="$CX" -v k="$K" -v y1="$Y1" 'BEGIN{printf "%.2f %.2f", cx-k, y1}') ${CX} ${Y1} c
f
"
}

# =============================================================================
# SECTION 4: PAGE MANAGEMENT
# =============================================================================

_MR_PAGES=()
_MR_CUR=""
_MR_Y=$MR_TOP_Y
_MR_BG="$MR_C_SURFACE"
_MR_FOOTER=1
_MR_PAGE_NO=0

_mr_background() {
    _MR_CUR="${_MR_BG} rg
0 0 ${MR_PAGE_W} ${MR_PAGE_H} re f
"
}

_mr_page_header() {
    _mr_text "$MR_MARGIN" 766 "ICEWARP HEALTH ASSESSMENT" "F2" 6.8 "$MR_C_TEAL_DARK"
    _mr_text_right "$MR_RIGHT" 766 "MANAGEMENT SUMMARY" "F1" 6.8 "$MR_C_MUTED"
    _mr_line "$MR_MARGIN" 754 "$MR_RIGHT" 754 0.6 "$MR_C_BORDER"
    _MR_Y=732
}

_mr_page_footer() {
    _mr_line "$MR_MARGIN" 40 "$MR_RIGHT" 40 0.5 "$MR_C_BORDER"
    _mr_text "$MR_MARGIN" 27 "PARSAVAN  |  ICEWARP HEALTH AGENT" "F1" 6.2 "$MR_C_MUTED"
    _mr_text "$((MR_MARGIN + 190))" 27 "CONFIDENTIAL" "F1" 6.2 "$MR_C_MUTED"
    _mr_text_right "$MR_RIGHT" 27 "Page ${_MR_PAGE_NO}" "F1" 6.2 "$MR_C_MUTED"
}

_mr_new_page() {
    if [ -n "$_MR_CUR" ]; then
        [ "$_MR_FOOTER" = "1" ] && _mr_page_footer
        _MR_PAGES+=("$_MR_CUR")
    fi
    _MR_CUR=""
    _MR_PAGE_NO=$((_MR_PAGE_NO + 1))
    _mr_background
    if [ "$_MR_FOOTER" = "1" ]; then
        _mr_page_header
    else
        _MR_Y=$MR_TOP_Y
    fi
}

_mr_ensure() {
    if [ "$((_MR_Y - $1))" -lt "$MR_BOTTOM_Y" ]; then _mr_new_page; fi
}

_mr_finish() {
    if [ -n "$_MR_CUR" ]; then
        [ "$_MR_FOOTER" = "1" ] && _mr_page_footer
        _MR_PAGES+=("$_MR_CUR")
    fi
}

# Parser callback: records the active checklist section for collection.
_mr_section_header() {
    local SEC="$1"
    _MR_CUR_SECTION="$SEC"
    if [ -z "${_MR_SEC_SEEN[$SEC]:-}" ]; then
        _MR_SEC_SEEN["$SEC"]=1
        _MR_SECTION_ORDER+=("$SEC")
        _MR_SEC_PASS["$SEC"]=0
        _MR_SEC_WARN["$SEC"]=0
        _MR_SEC_CRIT["$SEC"]=0
        _MR_SEC_INFO["$SEC"]=0
        _MR_SEC_NA["$SEC"]=0
    fi
}

_mr_section_title() {
    local NUM="$1" TITLE="$2" SUB="${3:-}"
    _mr_ensure 58
    _mr_text "$MR_MARGIN" "$_MR_Y" "${NUM}  /  ${TITLE^^}" "F2" 7.2 "$MR_C_TEAL_DARK"
    _MR_Y=$((_MR_Y - 22))
    _mr_text "$MR_MARGIN" "$_MR_Y" "$TITLE" "F2" 19 "$MR_C_TEXT"
    if [ -n "$SUB" ]; then
        _MR_Y=$((_MR_Y - 16))
        _mr_text "$MR_MARGIN" "$_MR_Y" "$SUB" "F1" 8.4 "$MR_C_MUTED"
    fi
    _MR_Y=$((_MR_Y - 12))
    _mr_line "$MR_MARGIN" "$_MR_Y" "$MR_RIGHT" "$_MR_Y" 0.8 "$MR_C_BORDER"
    _MR_Y=$((_MR_Y - 18))
}


# =============================================================================
# SECTION 5: CHECKLIST COLLECTION
# =============================================================================
# The management report deliberately does not print the 100+ item checklist.
# The same evaluator runs, but results are collected into section scorecards,
# an executive distribution and a short priority list.

_MR_CUR_SECTION=""
_MR_TOTAL=0
_MR_PASS=0
_MR_WARN=0
_MR_CRIT=0
_MR_INFO=0
_MR_NA=0
_MR_SECTION_ORDER=()
_MR_ISSUES=()
declare -Ag _MR_SEC_SEEN
declare -Ag _MR_SEC_PASS
declare -Ag _MR_SEC_WARN
declare -Ag _MR_SEC_CRIT
declare -Ag _MR_SEC_INFO
declare -Ag _MR_SEC_NA

_mr_priority() {
    case "$1" in
        "Backup, Watchdog and Monitoring")              echo 1 ;;
        "DNS & Mail Flow Verification")                  echo 2 ;;
        "Storage, Certificates and Services")            echo 3 ;;
        "Intrusion Prevention - Block Rules")            echo 4 ;;
        "Rejection Rules and Access")                    echo 5 ;;
        "SMTP Protocol Hardening")                       echo 6 ;;
        "Protocol and Access Hardening")                 echo 7 ;;
        "SMTP Delivery Settings")                        echo 8 ;;
        "APP OS / Infrastructure")                       echo 9 ;;
        "Database"|"MySQL Server (Remote DB)")           echo 10 ;;
        *)                                               echo 20 ;;
    esac
}

_mr_grid_reset() { :; }

_mr_grid_item() {
    local LABEL="$1" STATUS="$2"
    local SEC="${_MR_CUR_SECTION:-Uncategorised}"
    [ -z "${_MR_SEC_SEEN[$SEC]:-}" ] && _mr_section_header "$SEC"

    _MR_TOTAL=$((_MR_TOTAL + 1))
    case "$STATUS" in
        PASS)
            _MR_PASS=$((_MR_PASS + 1))
            _MR_SEC_PASS["$SEC"]=$(( ${_MR_SEC_PASS[$SEC]:-0} + 1 ))
            ;;
        WARN)
            _MR_WARN=$((_MR_WARN + 1))
            _MR_SEC_WARN["$SEC"]=$(( ${_MR_SEC_WARN[$SEC]:-0} + 1 ))
            _MR_ISSUES+=("$(_mr_priority "$SEC")|2|${SEC}|${LABEL}|WARN")
            ;;
        CRITICAL|FAIL)
            _MR_CRIT=$((_MR_CRIT + 1))
            _MR_SEC_CRIT["$SEC"]=$(( ${_MR_SEC_CRIT[$SEC]:-0} + 1 ))
            _MR_ISSUES+=("$(_mr_priority "$SEC")|1|${SEC}|${LABEL}|CRITICAL")
            ;;
        INFO)
            _MR_INFO=$((_MR_INFO + 1))
            _MR_SEC_INFO["$SEC"]=$(( ${_MR_SEC_INFO[$SEC]:-0} + 1 ))
            ;;
        *)
            _MR_NA=$((_MR_NA + 1))
            _MR_SEC_NA["$SEC"]=$(( ${_MR_SEC_NA[$SEC]:-0} + 1 ))
            ;;
    esac
}

_mr_grid_end_row() { :; }

_mr_section_status() {
    local SEC="$1"
    if [ "${_MR_SEC_CRIT[$SEC]:-0}" -gt 0 ]; then echo "CRITICAL"
    elif [ "${_MR_SEC_WARN[$SEC]:-0}" -gt 0 ]; then echo "WARN"
    elif [ "${_MR_SEC_PASS[$SEC]:-0}" -gt 0 ]; then echo "PASS"
    elif [ "${_MR_SEC_INFO[$SEC]:-0}" -gt 0 ]; then echo "INFO"
    else echo "NA"; fi
}

# =============================================================================
# SECTION 6: PDF LOW-LEVEL WRITER
# =============================================================================

_mr_obj() {
    MR_OFFSETS[$1]="$(wc -c < "$MR_OUT_FILE")"
    printf '%s' "$2" >> "$MR_OUT_FILE"
}

_mr_write_file() {
    local OUT_PDF="$1"
    local P="${#_MR_PAGES[@]}"
    [ "$P" -eq 0 ] && { echo "[WARN] management report: nothing to render" >&2; return 1; }

    local F_REG=$((2 + 2*P + 1)) F_BOLD=$((2 + 2*P + 2)) F_OBL=$((2 + 2*P + 3))
    declare -Ag MR_OFFSETS=()
    MR_OUT_FILE="$OUT_PDF"

    : > "$OUT_PDF"
    printf '%%PDF-1.4\n' >> "$OUT_PDF"
    _mr_obj 1 "1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
"
    local KIDS="" i
    for ((i=1; i<=P; i++)); do KIDS="${KIDS}$((2+i)) 0 R "; done
    _mr_obj 2 "2 0 obj
<< /Type /Pages /Kids [ ${KIDS}] /Count ${P} >>
endobj
"
    for ((i=1; i<=P; i++)); do
        local PN=$((2+i)) CN=$((2+P+i))
        local STREAM="${_MR_PAGES[$((i-1))]}"
        local SLEN; SLEN="$(printf '%s' "$STREAM" | wc -c)"
        _mr_obj "$PN" "${PN} 0 obj
<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 ${F_REG} 0 R /F2 ${F_BOLD} 0 R /F3 ${F_OBL} 0 R >> >> /MediaBox [0 0 ${MR_PAGE_W} ${MR_PAGE_H}] /Contents ${CN} 0 R >>
endobj
"
        _mr_obj "$CN" "${CN} 0 obj
<< /Length ${SLEN} >>
stream
${STREAM}
endstream
endobj
"
    done
    _mr_obj "$F_REG" "${F_REG} 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
"
    _mr_obj "$F_BOLD" "${F_BOLD} 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>
endobj
"
    _mr_obj "$F_OBL" "${F_OBL} 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique >>
endobj
"
    local XSTART; XSTART="$(wc -c < "$OUT_PDF")"
    local TOTAL=$((F_OBL + 1))
    {
        printf 'xref\n0 %d\n' "$TOTAL"
        printf '0000000000 65535 f \n'
        local n
        for ((n=1; n<=F_OBL; n++)); do printf '%010d 00000 n \n' "${MR_OFFSETS[$n]}"; done
        printf 'trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n' "$TOTAL" "$XSTART"
    } >> "$OUT_PDF"
    echo "[INFO] Management report written: $OUT_PDF ($(wc -c < "$OUT_PDF") bytes, ${P} page(s))"
}

# =============================================================================
# SECTION 7: DATE AND VALIDATION HELPERS
# =============================================================================

_days_ago() {
    local date_str="$1"
    [[ -z "$date_str" ]] && echo "999"
    local date_epoch=$(date -d "$date_str" +%s 2>/dev/null)
    [[ -z "$date_epoch" ]] && echo "999"
    echo $(( ( $(date +%s) - date_epoch ) / 86400 ))
}

_validate_intrusion_value() {
    local KEY="$1"
    local VALUE="$2"
    local EXPECTED=""
    case "$KEY" in
        "security.intrusion.block_connections_per_minute.value") EXPECTED="50" ;;
        "security.intrusion.block_unknown_user_count.value") EXPECTED="5" ;;
        "security.intrusion.block_relay_denied_count.value") EXPECTED="5" ;;
        "security.intrusion.block_rset_count.value") EXPECTED="5" ;;
        "security.intrusion.block_spam_score.value") EXPECTED="9.00" ;;
        "security.intrusion.block_failed_logins.value") EXPECTED="5" ;;
        "security.intrusion.block_duration_minutes") EXPECTED="360" ;;
        *) echo "WARN" ;;
    esac
    if [ -z "$VALUE" ]; then
        echo "CRITICAL"
    elif [[ "$VALUE" == "$EXPECTED" ]]; then
        echo "PASS"
    else
        echo "WARN"
    fi
}

# =============================================================================
# SECTION 8: MAIN CHECKLIST RENDERER
# =============================================================================

_mr_render_checklist() {
    local CHECKLIST_FILE="${PROJECT_ROOT}/config/checklist.conf.pdf"
    local CUR_SECTION=""

    if [ ! -f "$CHECKLIST_FILE" ]; then
        _mr_grid_item "Checklist file not found" "NA"
        return
    fi

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        line=$(echo "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$line" ] && continue

        IFS='~' read -r SECTION LABEL KIND KEYS NOTE <<< "$line"

        if [ "$SECTION" != "$CUR_SECTION" ]; then
            [ -n "$CUR_SECTION" ] && _mr_grid_end_row
            _mr_section_header "$SECTION"
            CUR_SECTION="$SECTION"
            _mr_grid_reset
        fi

        # ---- Special case: MySQL Server section ----
        if [[ "$SECTION" == "MySQL Server"* ]] && [ "${DATA[database.scope]:-}" != "remote" ]; then
            _mr_grid_item "$LABEL" "NA"
            continue
        fi

        # ---- Special case: MySQL items in Database section ----
        if [[ "$SECTION" == "Database" ]] && [[ "$LABEL" == MySQL* ]] && [[ "${DATA[mysql.applicable]:-false}" != "true" ]]; then
            _mr_grid_item "$LABEL" "NA"
            continue
        fi

        # ---- Special case: Database Type (Strict Override: SQLite=WARN, MySQL=PASS, no INFO) ----
        if [ "$LABEL" = "Database Type" ]; then
            local DB_TYPE="${DATA[database.type]:-}"
            if [ "$DB_TYPE" = "sqlite" ]; then
                _mr_grid_item "$LABEL" "WARN"
            elif [ "$DB_TYPE" = "mysql" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "WARN"
            fi
            continue
        fi

        # ---- Special case: customers-stat email ----
        if [ "$LABEL" = "Set customers-stat@parsavan.com" ]; then
            local RAW="${DATA[monitor.alert_email]:-}"
            if [[ "$RAW" == *"customers-stat@parsavan.com"* ]] || [[ "$RAW" == *"customers-stat"* ]]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        # ---- Special case: Set Admin Email (Strict Override: empty=CRITICAL, invalid=WARN) ----
        if [ "$LABEL" = "Set Admin Email" ]; then
            local RAW="${DATA[monitor.alert_email]:-}"
            if [ -z "$RAW" ] || [ "$RAW" = "null" ] || [ "$RAW" = "N/A" ]; then
                _mr_grid_item "$LABEL" "CRITICAL"
            elif [[ "$RAW" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "WARN"
            fi
            continue
        fi

        # ---- Special case: Session Timeout (Strict Override: has value=PASS, missing=WARN) ----
        if [ "$LABEL" = "Session Timeout" ]; then
            local RAW="${DATA[icewarp.session_timeout_minutes]:-}"
            if [ -n "$RAW" ] && [ "$RAW" != "null" ] && [ "$RAW" != "N/A" ] && [ "$RAW" != "0" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "WARN"
            fi
            continue
        fi

        # ---- Special case: Certificates ----
        if [ "$LABEL" = "Check for Certificates" ]; then
            local DAYS_LEFT="${DATA[icewarp.ssl.days_left]:-0}"
            local STATUS="INFO"
            if [[ "$DAYS_LEFT" -gt 90 ]]; then STATUS="PASS"
            elif [[ "$DAYS_LEFT" -gt 30 ]]; then STATUS="WARN"
            else STATUS="CRITICAL"
            fi
            _mr_grid_item "$LABEL" "$STATUS"
            continue
        fi

        # ---- Special case: Last Backup Date ----
        if [ "$LABEL" = "Last Backup Date and Time" ]; then
            local BACKUP_TIME="${DATA[icewarp.backup.last_time]:-}"
            local STATUS="NA"
            if [ -n "$BACKUP_TIME" ]; then
                local DAYS=$(_days_ago "$BACKUP_TIME")
                if [ "$DAYS" -lt 2 ]; then STATUS="PASS"
                elif [ "$DAYS" -lt 4 ]; then STATUS="WARN"
                else STATUS="CRITICAL"
                fi
            else
                STATUS="CRITICAL"
            fi
            _mr_grid_item "$LABEL" "$STATUS"
            continue
        fi

        # ---- Special case: 2FA ----
        if [ "$LABEL" = "2FA" ]; then
            local RAW="${DATA[security.login.2fa_bypass_enabled]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "WARN"
            else
                _mr_grid_item "$LABEL" "PASS"
            fi
            continue
        fi

        # ---- Special case: Hide Server Version ----
        if [ "$LABEL" = "Hide Server Version" ]; then
            local RAW="${DATA[smtp.hide_server_version]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        # ---- Special case: Port 9001 ----
        if [ "$LABEL" = "Block Outgoing Port 9001" ]; then
            local RAW="${DATA[security.port_9001_egress.blocked]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        # ---- Special case: AntiSpam Folders ----
        if [ "$LABEL" = "Remove Old AntiSpam Folders" ]; then
            local STATUS="${DATA[security.cyren_folder.status]:-INFO}"
            case "$STATUS" in
                OK) _mr_grid_item "$LABEL" "PASS" ;;
                WARN) _mr_grid_item "$LABEL" "WARN" ;;
                *) _mr_grid_item "$LABEL" "INFO" ;;
            esac
            continue
        fi

        # ---- Special case: AntiSpam Live ----
        if [ "$LABEL" = "Disable AntiSpam Live" ]; then
            local RAW="${DATA[security.antispam_live.enabled]:-}"
            if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "WARN"
            fi
            continue
        fi

        # ---- Special case: Process POP3/IMAP ----
        if [ "$LABEL" = "Process POP3/IMAP" ]; then
            local RAW="${DATA[security.intrusion.process_pop3_imap]:-0}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        # ---- Special case: Cloud Features (CHANGED to WARN for enabled) ----
        if [ "$LABEL" = "Disable Cloud Features" ]; then
            local RAW="${DATA[icewarp.cloud_api.autoconfigure]:-}"
            if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            elif [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "WARN"
            else
                _mr_grid_item "$LABEL" "NA"
            fi
            continue
        fi

        # ---- Special case: DIGEST-MD5 ----
        if [ "$LABEL" = "Disable DIGEST-MD5" ]; then
            local RAW="${DATA[security.digest_md5.enabled]:-}"
            if [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "CRITICAL"
            elif [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        # ---- Special case: IMAP / POP3 (Strict Override: Disabled=PASS, Enabled=WARN) ----
        if [ "$LABEL" = "Disable IMAP" ] || [ "$LABEL" = "Disable POP3" ]; then
            local RAW="${DATA[${KEYS}]:-1}"
            if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "WARN"
            fi
            continue
        fi

        # ---- Special case: VRFY ----
        if [ "$LABEL" = "Disable VRFY" ]; then
            local RAW="${DATA[smtp.deny_vrfy]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            elif [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _mr_grid_item "$LABEL" "CRITICAL"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        # ---- Special case: License ----
        if [ "$LABEL" = "Number of Used Seats / License Max Users" ]; then
            local RAW="${DATA[icewarp.license.used_seats_note]:-}"
            if [ -z "$RAW" ] || [[ "$RAW" == *"not available"* ]]; then
                _mr_grid_item "$LABEL" "WARN"
            else
                _mr_grid_item "$LABEL" "INFO"
            fi
            continue
        fi

        # ---- Special case: Daytime Clock ----
        if [ "$LABEL" = "Enable Daytime Clock Synchronization" ]; then
            local RAW="${DATA[icewarp.daytime_clock_sync.enabled]:-}"
            if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                _mr_grid_item "$LABEL" "PASS"
            elif [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                _mr_grid_item "$LABEL" "CRITICAL"
            else
                _mr_grid_item "$LABEL" "WARN"
            fi
            continue
        fi

        # ---- Special case: System Backup ----
        if [ "$LABEL" = "Enable System Backup" ]; then
            local RAW="${DATA[icewarp.backup.auto_enabled]:-0}"
            if [ "$RAW" = "1" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        # ---- Special case: Database Backup (legacy) ----
        if [ "$LABEL" = "Enable Database Backup" ]; then
            local RAW="${DATA[icewarp.database_backup.enabled]:-0}"
            if [ "$RAW" = "1" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        # ---- Special case: Maximum Threads ----
        if [ "$LABEL" = "Maximum Number of Simultaneous Threads" ]; then
            local RAW="${DATA[smtp.incoming_queue_threads]:-}"
            local STATUS="INFO"
            if [ -z "$RAW" ]; then
                STATUS="CRITICAL"
            elif [ "$RAW" = "10" ]; then
                STATUS="PASS"
            else
                STATUS="WARN"
            fi
            _mr_grid_item "$LABEL" "$STATUS"
            continue
        fi

        # ---- Special case: Directory Cache ----
        if [ "$LABEL" = "Set Directory Cache Schedule" ]; then
            local RAW="${DATA[directory_cache.scheduled]:-}"
            if [ "$RAW" = "1" ] || [ "$RAW" = "true" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        # ---- Watchdog items (main + individual) ----
        if [ "$LABEL" = "Enable System Watchdog" ]; then
            local CTRL="${DATA[watchdog.control]:-0}"
            if [ "$CTRL" = "1" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "Watchdog - SMTP" ]; then
            local VAL="${DATA[watchdog.smtp]:-0}"
            if [ "$VAL" = "1" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "Watchdog - POP3/IMAP" ]; then
            local VAL="${DATA[watchdog.pop3]:-0}"
            if [ "$VAL" = "1" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "Watchdog - IM/VoIP" ]; then
            local VAL="${DATA[watchdog.im]:-0}"
            if [ "$VAL" = "1" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "Watchdog - GroupWare" ]; then
            local VAL="${DATA[watchdog.gw]:-0}"
            if [ "$VAL" = "1" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        if [ "$LABEL" = "Watchdog Interval" ]; then
            local INTERVAL="${DATA[watchdog.interval_minutes]:-0}"
            local STATUS="INFO"
            if [ "$INTERVAL" -eq 0 ]; then
                STATUS="PASS"
            elif [ "$INTERVAL" -ge 1 ] && [ "$INTERVAL" -le 60 ]; then
                STATUS="PASS"
            elif [ "$INTERVAL" -gt 60 ] && [ "$INTERVAL" -le 1440 ]; then
                STATUS="WARN"
            else
                STATUS="CRITICAL"
            fi
            _mr_grid_item "$LABEL" "$STATUS"
            continue
        fi

        # ---- NEW: Special case for Integrate Archive with IMAP Folder ----
        if [ "$LABEL" = "Integrate Archive with IMAP Folder" ]; then
            local RAW="${DATA[archive.integrate_with_imap]:-0}"
            if [ "$RAW" = "1" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "CRITICAL"
            fi
            continue
        fi

        # ============================================================
        # Intrusion Prevention validation (BEFORE general V handling)
        # ============================================================
        if [ "$KIND" = "V" ] && [[ "$KEYS" == security.intrusion.*.value* || "$KEYS" == "security.intrusion.block_duration_minutes" ]]; then
            local RAW="${DATA[$KEYS]:-}"
            local STATUS="$(_validate_intrusion_value "$KEYS" "$RAW")"
            _mr_grid_item "$LABEL" "$STATUS"
            continue
        fi

        # ============================================================
        # APP OS / Infrastructure items (KIND=V with specific LABELs)
        # ============================================================
        if [ "$KIND" = "V" ]; then
            case "$LABEL" in
                "Disk (Total GB / Used %)")
                    local USED_PERCENT="${DATA[storage.root_fs.used_percent]:-0}"
                    local STATUS="INFO"
                    if _is_num "$USED_PERCENT"; then
                        if [ "$USED_PERCENT" -ge 95 ]; then STATUS="CRITICAL"
                        elif [ "$USED_PERCENT" -ge 80 ]; then STATUS="WARN"
                        else STATUS="PASS"
                        fi
                    fi
                    _mr_grid_item "$LABEL" "$STATUS"
                    continue
                    ;;
                "CPU Usage")
                    local LOAD15="${DATA[os.cpu.load15]:-0}"
                    local CORES="${DATA[os.cpu.count]:-1}"
                    local CPU_PERCENT=0
                    local STATUS="INFO"
                    if _is_num "$LOAD15" && _is_num "$CORES" && [ "$CORES" -gt 0 ]; then
                        CPU_PERCENT=$(awk -v l="$LOAD15" -v c="$CORES" 'BEGIN{printf "%.2f", (l/c)*100}')
                        if awk -v cpu="$CPU_PERCENT" -v lim=95 'BEGIN{exit !(cpu > lim)}'; then STATUS="CRITICAL"
                        elif awk -v cpu="$CPU_PERCENT" -v lim=50 'BEGIN{exit !(cpu > lim)}'; then STATUS="WARN"
                        else STATUS="PASS"
                        fi
                    fi
                    _mr_grid_item "$LABEL" "$STATUS"
                    continue
                    ;;
                "RAM (Total KB / Available KB)")
                    local TOTAL_KB="${DATA[os.memory.total_kb]:-0}"
                    local AVAIL_KB="${DATA[os.memory.available_kb]:-0}"
                    local USED_PERCENT=0
                    local STATUS="INFO"
                    if _is_num "$TOTAL_KB" && _is_num "$AVAIL_KB" && [ "$TOTAL_KB" -gt 0 ]; then
                        USED_PERCENT=$(awk -v t="$TOTAL_KB" -v a="$AVAIL_KB" 'BEGIN{printf "%.2f", ((t-a)/t)*100}')
                        if awk -v used="$USED_PERCENT" -v lim=90 'BEGIN{exit !(used > lim)}'; then STATUS="CRITICAL"
                        elif awk -v used="$USED_PERCENT" -v lim=40 'BEGIN{exit !(used > lim)}'; then STATUS="WARN"
                        else STATUS="PASS"
                        fi
                    fi
                    _mr_grid_item "$LABEL" "$STATUS"
                    continue
                    ;;
                "APP OS Last Update")
                    local LAST_UPDATE="${DATA[os.last_update_date]:-}"
                    local STATUS="INFO"
                    if [ -n "$LAST_UPDATE" ] && [ "$LAST_UPDATE" != "N/A" ] && [ "$LAST_UPDATE" != "null" ]; then
                        local DAYS=$(_days_ago "$LAST_UPDATE")
                        if [ "$DAYS" -le 7 ]; then STATUS="PASS"
                        elif [ "$DAYS" -le 30 ]; then STATUS="WARN"
                        else STATUS="CRITICAL"
                        fi
                    fi
                    _mr_grid_item "$LABEL" "$STATUS"
                    continue
                    ;;
                "Swap Usage (7 days)")
                    local STATUS="${DATA[system.swap.status]:-INFO}"
                    case "$STATUS" in
                        PASS) _mr_grid_item "$LABEL" "PASS" ;;
                        CRITICAL) _mr_grid_item "$LABEL" "CRITICAL" ;;
                        *) _mr_grid_item "$LABEL" "INFO" ;;
                    esac
                    continue
                    ;;
                "Database Scope")
                    local SCOPE="${DATA[database.scope]:-unknown}"
                    _mr_grid_item "$LABEL" "PASS"
                    continue
                    ;;
            esac
            # Fallback for generic V items
            _mr_grid_item "$LABEL" "$([ -n "${DATA[$KEYS]:-}" ] && echo "INFO" || echo "NA")"
            continue
        fi

        # ============================================================
        # Other KIND types
        # ============================================================

        if [ "$KIND" = "T" ]; then
            local RAW="${DATA[$KEYS]:-}"
            local EXPECTED="$NOTE"
            if [ "$RAW" = "$EXPECTED" ]; then
                _mr_grid_item "$LABEL" "PASS"
            else
                _mr_grid_item "$LABEL" "WARN"
            fi
            continue
        fi

        local RAW="${DATA[$KEYS]:-}"
        case "$KIND" in
            F)
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _mr_grid_item "$LABEL" "PASS"
                elif [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                    _mr_grid_item "$LABEL" "CRITICAL"
                else
                    _mr_grid_item "$LABEL" "NA"
                fi
                ;;
            B)
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _mr_grid_item "$LABEL" "PASS"
                else
                    _mr_grid_item "$LABEL" "CRITICAL"
                fi
                ;;
            R)
                if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                    _mr_grid_item "$LABEL" "PASS"
                elif [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _mr_grid_item "$LABEL" "CRITICAL"
                else
                    _mr_grid_item "$LABEL" "NA"
                fi
                ;;
            V)
                if [ "$LABEL" = "APP OS Last Update" ]; then
                    local LAST_UPDATE="${DATA[os.last_update_date]:-}"
                    local STATUS="INFO"
                    if [ -n "$LAST_UPDATE" ] && [ "$LAST_UPDATE" != "N/A" ] && [ "$LAST_UPDATE" != "null" ]; then
                        local DAYS=$(_days_ago "$LAST_UPDATE")
                        if [ "$DAYS" -le 7 ]; then STATUS="PASS"
                        elif [ "$DAYS" -le 30 ]; then STATUS="WARN"
                        else STATUS="CRITICAL"
                        fi
                    fi
                    _mr_grid_item "$LABEL" "$STATUS"
                else
                    _mr_grid_item "$LABEL" "$([ -n "$RAW" ] && echo "INFO" || echo "NA")"
                fi
                ;;
            L)
                local RAW="${DATA[$KEYS]:-}"
                if [[ -n "$RAW" ]] && [[ "$RAW" != "0" ]]; then
                    _mr_grid_item "$LABEL" "PASS"
                elif [[ "$RAW" == "0" ]]; then
                    _mr_grid_item "$LABEL" "CRITICAL"
                else
                    _mr_grid_item "$LABEL" "INFO"
                fi
                ;;
            P)
                if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]] || [ -z "$RAW" ]; then
                    _mr_grid_item "$LABEL" "PASS"
                else
                    _mr_grid_item "$LABEL" "CRITICAL"
                fi
                ;;
            Z)
                if [ "$RAW" = "0" ]; then
                    _mr_grid_item "$LABEL" "WARN"
                elif [ -n "$RAW" ]; then
                    _mr_grid_item "$LABEL" "INFO"
                else
                    _mr_grid_item "$LABEL" "NA"
                fi
                ;;
            M)
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _mr_grid_item "$LABEL" "WARN"
                else
                    _mr_grid_item "$LABEL" "PASS"
                fi
                ;;
            G)
                if [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _mr_grid_item "$LABEL" "PASS"
                else
                    _mr_grid_item "$LABEL" "CRITICAL"
                fi
                ;;
            D)
                # KIND D: 0/disabled = PASS, 1/enabled = WARN
                if [[ "$RAW" == "0" ]] || [[ "$RAW" == "false" ]] || [[ "$RAW" == "FALSE" ]] || [[ "$RAW" == "False" ]]; then
                    _mr_grid_item "$LABEL" "PASS"
                elif [[ "$RAW" == "1" ]] || [[ "$RAW" == "true" ]] || [[ "$RAW" == "TRUE" ]] || [[ "$RAW" == "True" ]]; then
                    _mr_grid_item "$LABEL" "WARN"
                else
                    _mr_grid_item "$LABEL" "NA"
                fi
                ;;
            H)
                local WORST="PASS" K RESULT
                IFS=',' read -ra _HK <<< "$KEYS"
                for K in "${_HK[@]}"; do
                    RESULT="${HEALTH[$K]:-skip}"
                    [ "$RESULT" = "fail" ] && WORST="CRITICAL"
                    [ "$RESULT" = "warn" ] && [ "$WORST" != "CRITICAL" ] && WORST="WARN"
                done
                _mr_grid_item "$LABEL" "$WORST"
                ;;
            *)
                if [ -n "$RAW" ]; then
                    _mr_grid_item "$LABEL" "INFO"
                else
                    _mr_grid_item "$LABEL" "NA"
                fi
                ;;
        esac
    done < "$CHECKLIST_FILE"
    _mr_grid_end_row
}

# =============================================================================
# SECTION 9: COVER LETTER
# =============================================================================

_mr_cover_letter() {
    local HOST="${DATA[agent.hostname]:-unknown}"
    local GEN="${DATA[agent.time]:-unknown}"
    local COMPANY="${DATA[general.company]:-Unknown}"
    local DOMAIN="${DATA[domain.primary.name]:-not returned}"
    local TECHNICIAN="${DATA[general.technician]:-Parsavan}"
    local DATE_TXT
    DATE_TXT="$(date -d "$GEN" '+%d %B %Y' 2>/dev/null || echo "$GEN")"
    local OVERALL="${_MR_OVERALL:-pass}"
    local SCORE="${_MR_SCORE:-0}"
    local AREAS="${#_MR_SECTION_ORDER[@]}"

    _MR_FOOTER=0
    _MR_BG="$MR_C_INK"
    _MR_PAGE_NO=1
    _MR_Y=$MR_TOP_Y
    _mr_background

    # Subtle technical grid and layered rings: cyberpunk structure, low noise.
    local I
    for ((I=0; I<=MR_PAGE_W; I+=36)); do
        _mr_line "$I" 0 "$I" "$MR_PAGE_H" 0.3 "$MR_C_GRID"
    done
    for ((I=0; I<=MR_PAGE_H; I+=36)); do
        _mr_line 0 "$I" "$MR_PAGE_W" "$I" 0.3 "$MR_C_GRID"
    done
    _mr_circle 512 604 192 "0.060 0.085 0.125"
    _mr_ring 512 604 176 0.8 "0.100 0.180 0.220"
    _mr_ring 512 604 132 0.6 "0.120 0.220 0.260"

    _mr_rect "$MR_MARGIN" 716 8 8 "$MR_C_TEAL"
    _mr_text "$((MR_MARGIN + 14))" 716 "PARSAVAN" "F2" 8 "$MR_C_WHITE"
    _mr_text "$((MR_MARGIN + 82))" 716 "ICEWARP HEALTH AGENT" "F1" 7 "$MR_C_MUTED"
    _mr_text_right "$MR_RIGHT" 716 "CHECKLIST v${MR_CHECKLIST_VERSION}" "F1" 7 "$MR_C_TEAL_LIGHT"

    _mr_text "$MR_MARGIN" 640 "MANAGEMENT SUMMARY" "F2" 8.5 "$MR_C_TEAL_LIGHT"
    _mr_text "$MR_MARGIN" 600 "Health Check Report" "F2" 30 "$MR_C_WHITE"
    _mr_text "$MR_MARGIN" 570 "Mail security, resilience and service health at a glance." "F1" 10.5 "$MR_C_MUTED"

    _mr_line "$MR_MARGIN" 548 "$((MR_MARGIN + 112))" 548 2 "$MR_C_TEAL"

    _mr_text "$MR_MARGIN" 518 "PREPARED FOR" "F2" 6.8 "$MR_C_TEAL_LIGHT"
    _mr_text "$MR_MARGIN" 492 "$COMPANY" "F2" 19 "$MR_C_WHITE"
    _mr_text "$MR_MARGIN" 472 "$DOMAIN" "F1" 10 "$MR_C_MUTED"
    _mr_text "$MR_MARGIN" 452 "Server: ${HOST}   |   Generated: ${DATE_TXT}" "F1" 8 "$MR_C_MUTED"

    _mr_text "$MR_MARGIN" 430 "OVERALL POSTURE" "F1" 6.8 "$MR_C_MUTED"
    local PILL_FILL
    PILL_FILL="$(_mr_status_fill "$OVERALL")"
    _mr_round_rect "$MR_MARGIN" 398 196 30 8 "$PILL_FILL"
    _mr_text "$((MR_MARGIN + 12))" 408 "$(_mr_overall_word "$OVERALL")  |  ${SCORE}% pass rate" "F2" 8.6 "$(_mr_status_text_color "$OVERALL")"

    _mr_text "$MR_MARGIN" 366 "${_MR_TOTAL} controls assessed across ${AREAS} operational areas" "F1" 8.2 "$MR_C_MUTED"

    # Score ring
    _mr_ring 500 420 48 8 "$MR_C_INK_2"
    _mr_arc 500 420 48 5 "$(_mr_status_color "$OVERALL")" "$SCORE"
    _mr_circle 500 420 36 "$MR_C_INK"
    _mr_text_center 500 424 "${SCORE}%" "F2" 18 "$MR_C_WHITE"
    _mr_text_center 500 406 "CONTROL SCORE" "F1" 5.8 "$MR_C_MUTED"

    # Four headline metrics
    local KPI_Y=246 KPI_H=76 KPI_W=122 GAP=12
    local KPI_X="$MR_MARGIN"
    local -a KPI_LABELS=("CONTROLS" "HEALTHY" "REVIEW" "ACTION")
    local -a KPI_VALUES=("$_MR_TOTAL" "$_MR_PASS" "$_MR_WARN" "$_MR_CRIT")
    local -a KPI_COLORS=("$MR_C_TEAL" "$MR_C_GREEN" "$MR_C_AMBER" "$MR_C_ROSE")
    local K
    for K in 0 1 2 3; do
        _mr_dark_card "$KPI_X" "$KPI_Y" "$KPI_W" "$KPI_H" 9
        _mr_line "$KPI_X" "$((KPI_Y + KPI_H - 3))" "$((KPI_X + KPI_W))" "$((KPI_Y + KPI_H - 3))" 2 "${KPI_COLORS[$K]}"
        _mr_text "$((KPI_X + 12))" "$((KPI_Y + 44))" "${KPI_VALUES[$K]}" "F2" 22 "$MR_C_WHITE"
        _mr_text "$((KPI_X + 12))" "$((KPI_Y + 18))" "${KPI_LABELS[$K]}" "F1" 6.8 "$MR_C_MUTED"
        KPI_X=$((KPI_X + KPI_W + GAP))
    done

    _mr_line "$MR_MARGIN" 96 "$MR_RIGHT" 96 0.5 "0.120 0.170 0.230"
    _mr_text "$MR_MARGIN" 76 "Technician: ${TECHNICIAN}" "F1" 7 "$MR_C_MUTED"
    _mr_text "$((MR_MARGIN + 220))" 76 "Based on IceWarp CheckList v${MR_CHECKLIST_VERSION}" "F1" 7 "$MR_C_MUTED"
    _mr_text_right "$MR_RIGHT" 76 "CONFIDENTIAL" "F2" 7 "$MR_C_TEAL_LIGHT"
    _mr_text "$MR_MARGIN" 58 "This report is a management summary. The technical report contains item-level evidence and raw data." "F1" 6.4 "$MR_C_MUTED"

    _MR_FOOTER=0
    _MR_BG="$MR_C_SURFACE"
    _mr_new_page
    _MR_FOOTER=1
    _mr_page_header
}

# =============================================================================
# SECTION 10: MANAGEMENT DASHBOARD RENDERERS
# =============================================================================

_mr_display_label() {
    case "$1" in
        "Enable System Backup")                         echo "Automatic System Backup" ;;
        "Last Backup Date and Time")                    echo "Backup Freshness" ;;
        "Check DMARC")                                  echo "DMARC Record" ;;
        "Check SPF")                                    echo "SPF Record" ;;
        "Check DKIM")                                   echo "DKIM Record" ;;
        "Check PTR")                                    echo "PTR Record" ;;
        "Check TLS and Start TLS")                      echo "STARTTLS Support" ;;
        "Use TLS/SSL (Secured Delivery)")               echo "TLS for Delivery" ;;
        "Check for Certificates")                       echo "Certificate Validity" ;;
        "Password Policy Min Length")                   echo "Password Policy" ;;
        "2FA")                                          echo "2FA Bypass" ;;
        "Disable VRFY")                                 echo "SMTP VRFY" ;;
        "Block Outgoing Port 9001")                     echo "Outbound Port 9001" ;;
        "Hide Server Version")                          echo "SMTP Banner Version" ;;
        "Disable DIGEST-MD5")                           echo "DIGEST-MD5 Authentication" ;;
        "Disable Cloud Features")                       echo "Cloud Features" ;;
        "Disable AntiSpam Live")                        echo "AntiSpam Live" ;;
        "Process POP3/IMAP")                            echo "POP3/IMAP Intrusion Rules" ;;
        "Remove Old AntiSpam Folders")                  echo "Legacy AntiSpam Folders" ;;
        "Set Directory Cache Schedule")                 echo "Directory Cache Schedule" ;;
        "Change Admin URL")                             echo "Admin URL" ;;
        "Change Admin Port")                            echo "Admin Port" ;;
        "Set customers-stat@parsavan.com"|"Set Admin Email") echo "Alert Mailbox" ;;
        "Database Type")                                echo "Database Platform" ;;
        "APP OS Last Update")                           echo "OS Patch Level" ;;
        "Repository Access")                            echo "Package Repository Access" ;;
        "Time Sync (OS-level NTP)")                     echo "Time Synchronisation" ;;
        "Swap Usage (7 days)")                          echo "Swap Usage" ;;
        "CPU Usage")                                    echo "CPU Load" ;;
        "RAM (Total KB / Available KB)")                echo "Memory Headroom" ;;
        "Disk (Total GB / Used %)")                     echo "Disk Headroom" ;;
        "MySQL Service Active")                         echo "MySQL Service" ;;
        "MySQL Reachable (port 3306)")                  echo "MySQL Connectivity" ;;
        "Enable Full Text Search Services")             echo "Full-Text Search" ;;
        "Use DNSBL")                                    echo "DNSBL Checking" ;;
        "Use IP Reputation")                            echo "IP Reputation" ;;
        "Reject if Originators IP has no rDNS")         echo "Reject Missing rDNS" ;;
        "Reject if Originators Domain Does Not Exist")  echo "Reject Invalid Sender Domains" ;;
        "Reject if Originators Domain is Local and Not Authorized") echo "Reject Unauthorised Local Domains" ;;
        "Integrate Archive with IMAP Folder")           echo "Archive IMAP Integration" ;;
        "Archive Active")                               echo "Mail Archiving" ;;
        "Migration Active")                             echo "Migration Mode" ;;
        "Enable System Monitor (Mem/Disk/CPU)")         echo "System Monitor" ;;
        "Watchdog - SMTP")                              echo "SMTP Watchdog" ;;
        "Watchdog - POP3/IMAP")                         echo "POP3/IMAP Watchdog" ;;
        "Watchdog - IM/VoIP")                           echo "IM/VoIP Watchdog" ;;
        "Watchdog - GroupWare")                         echo "GroupWare Watchdog" ;;
        "RBL Valli Check (is our IP blacklisted)")      echo "RBL Blacklist Check" ;;
        *)                                              echo "$1" ;;
    esac
}

_mr_short_section() {
    case "$1" in
        "Backup, Watchdog and Monitoring")   echo "Backup & Recovery" ;;
        "DNS & Mail Flow Verification")       echo "Mail Flow" ;;
        "Storage, Certificates and Services") echo "Storage & Certificates" ;;
        "SMTP Protocol Hardening")            echo "SMTP Hardening" ;;
        "Rejection Rules and Access")         echo "Access Controls" ;;
        "Protocol and Access Hardening")      echo "Protocol Hardening" ;;
        "APP OS / Infrastructure")            echo "OS & Infrastructure" ;;
        "Intrusion Prevention - Block Rules") echo "Intrusion Prevention" ;;
        "SMTP Delivery Settings")             echo "SMTP Delivery" ;;
        "Database"|"MySQL Server (Remote DB)") echo "Database" ;;
        *)                                    echo "$1" ;;
    esac
}

_mr_join_sections() {
    local -a ITEMS=("$@")
    local N="${#ITEMS[@]}" I S OUT=""
    [ "$N" -eq 0 ] && return
    for I in "${!ITEMS[@]}"; do
        S="$(_mr_short_section "${ITEMS[$I]}")"
        if [ "$I" -eq 0 ]; then
            OUT="$S"
        elif [ "$I" -eq "$((N - 1))" ]; then
            OUT="$OUT and $S"
        else
            OUT="$OUT, $S"
        fi
    done
    printf '%s' "$OUT"
}

_mr_action_text() {
    local LABEL="$1" SECTION="$2"
    case "$LABEL" in
        "Enable System Backup")
            echo "Enable automatic backups and verify a recent restore point." ;;
        "Last Backup Date and Time")
            echo "Restore a daily backup schedule; the latest backup is stale." ;;
        "Enable Database Backup - Accounts")
            echo "Enable the Accounts database backup; it is the core recovery set." ;;
        "Enable Database Backup - AntiSpam")
            echo "Enable AntiSpam database backups to preserve filtering data." ;;
        "Enable Database Backup - GroupWare")
            echo "Enable GroupWare database backups to preserve collaboration data." ;;
        "Enable System Watchdog")
            echo "Enable the System Watchdog so failed services recover automatically." ;;
        "Enable System Monitor (Mem/Disk/CPU)")
            echo "Enable System Monitor and confirm alert thresholds." ;;
        "Watchdog - SMTP"|"Watchdog - POP3/IMAP"|"Watchdog - IM/VoIP"|"Watchdog - GroupWare")
            echo "Enable this service watchdog and verify that it can restart the service." ;;
        "Watchdog Interval")
            echo "Reduce the watchdog interval to one hour or less." ;;
        "Enable Daytime Clock Synchronization")
            echo "Enable time synchronisation for consistent logs and TLS." ;;
        "Check SPF")
            echo "Publish an SPF record for this server's sending IPs." ;;
        "Check DKIM")
            echo "Configure DKIM signing and publish the selector record in DNS." ;;
        "Check DMARC")
            echo "Publish a DMARC policy and route aggregate reports." ;;
        "Check PTR")
            echo "Create a matching PTR record for the public sending IP." ;;
        "Check TLS and Start TLS")
            echo "Enable STARTTLS on port 25 and verify a trusted certificate chain." ;;
        "Use TLS/SSL (Secured Delivery)"|"Enable SSL/TLS")
            echo "Enforce TLS for inbound and outbound mail delivery." ;;
        "Check for Certificates")
            echo "Replace the certificate before expiry and verify the full chain." ;;
        "Password Policy Min Length")
            echo "Enable the password policy and require at least eight characters." ;;
        "2FA")
            echo "Disable the 2FA bypass for administrative and user accounts." ;;
        "Disable VRFY")
            echo "Disable the SMTP VRFY command to reduce address harvesting." ;;
        "Block Outgoing Port 9001")
            echo "Block outbound port 9001 at the host firewall." ;;
        "Hide Server Version")
            echo "Hide the IceWarp version in SMTP banners." ;;
        "Disable DIGEST-MD5")
            echo "Remove DIGEST-MD5 from the enabled authentication schemes." ;;
        "Disable Cloud Features")
            echo "Disable unused cloud features to reduce external exposure." ;;
        "Disable AntiSpam Live")
            echo "Disable AntiSpam Live unless it is explicitly required." ;;
        "Process POP3/IMAP")
            echo "Enable intrusion processing for POP3 and IMAP." ;;
        "Remove Old AntiSpam Folders")
            echo "Remove or archive the legacy AntiSpam folders." ;;
        "Set Directory Cache Schedule")
            echo "Schedule the Directory Cache rebuild during a low-traffic window." ;;
        "Change Admin URL")
            echo "Move the admin interface off the default URL." ;;
        "Change Admin Port")
            echo "Move the admin interface off the default port." ;;
        "Set customers-stat@parsavan.com"|"Set Admin Email")
            echo "Set a monitored admin mailbox for alerts." ;;
        "Database Type")
            echo "Migrate production data to MySQL for reliability." ;;
        "RBL Valli Check (is our IP blacklisted)")
            echo "Request delisting and correct the sending-reputation issue." ;;
        "APP OS Last Update")
            echo "Apply pending operating-system security updates." ;;
        "Repository Access")
            echo "Restore package repository access for security updates." ;;
        "Time Sync (OS-level NTP)")
            echo "Enable NTP time synchronisation on the operating system." ;;
        "Swap Usage (7 days)")
            echo "Investigate sustained swap use; add RAM or reduce memory pressure." ;;
        "CPU Usage")
            echo "Investigate CPU pressure and reduce the load or add capacity." ;;
        "RAM (Total KB / Available KB)")
            echo "Investigate memory pressure; add RAM if usage remains sustained." ;;
        "Disk (Total GB / Used %)")
            echo "Free disk space or expand the volume before it reaches capacity." ;;
        "MySQL Service Active")
            echo "Start the MySQL service and verify that it starts at boot." ;;
        "MySQL Reachable (port 3306)")
            echo "Restore network access to the remote MySQL host on port 3306." ;;
        "Enable Full Text Search Services")
            echo "Disable full-text search if it is not required for this deployment." ;;
        "Use DNSBL")
            echo "Enable DNSBL checking in the mail security policy." ;;
        "Use IP Reputation")
            echo "Enable IP reputation screening in the mail security policy." ;;
        "Reject if Originators IP has no rDNS")
            echo "Reject senders without reverse DNS to reduce spoofed traffic." ;;
        "Reject if Originators Domain Does Not Exist")
            echo "Reject mail from non-existent sender domains." ;;
        "Reject if Originators Domain is Local and Not Authorized")
            echo "Reject unauthorised use of local domains." ;;
        "Integrate Archive with IMAP Folder")
            echo "Enable archive integration so users can search retained mail." ;;
        "Archive Active")
            echo "Enable archiving to meet retention and legal-hold requirements." ;;
        *)
            if [ "$SECTION" = "Backup, Watchdog and Monitoring" ]; then
                echo "Restore this resilience control and verify it during the next maintenance window."
            elif [ "$SECTION" = "DNS & Mail Flow Verification" ]; then
                echo "Correct the DNS or mail-flow record and re-test from an external resolver."
            else
                echo "Bring this control in line with the IceWarp hardening baseline."
            fi
            ;;
    esac
}

_mr_legend_item() {
    local X="$1" Y="$2" STATUS="$3" LABEL="$4" COUNT="$5"
    _mr_circle "$((X + 4))" "$((Y + 3))" 4 "$(_mr_status_color "$STATUS")"
    _mr_text "$((X + 13))" "$Y" "${LABEL}  ${COUNT}" "F1" 7.4 "$MR_C_MUTED"
}

_mr_executive_overview() {
    local SCORED=$((_MR_PASS + _MR_WARN + _MR_CRIT))
    local AREAS="${#_MR_SECTION_ORDER[@]}"
    local NARRATIVE TOP_TEXT=""
    local -a TOP_SECS=()
    local ISSUE PRI RANK SEC LABEL STATUS S

    if [ "${#_MR_SORTED_ISSUES[@]}" -gt 0 ]; then
        for ISSUE in "${_MR_SORTED_ISSUES[@]}"; do
            IFS='|' read -r PRI RANK SEC LABEL STATUS <<< "$ISSUE"
            [ "$STATUS" = "CRITICAL" ] || continue
            local SEEN=0
            for S in "${TOP_SECS[@]}"; do [ "$S" = "$SEC" ] && SEEN=1; done
            [ "$SEEN" -eq 0 ] && TOP_SECS+=("$SEC")
            [ "${#TOP_SECS[@]}" -ge 2 ] && break
        done
    fi
    if [ "${#TOP_SECS[@]}" -eq 0 ] && [ "$_MR_WARN" -gt 0 ]; then
        for ISSUE in "${_MR_SORTED_ISSUES[@]}"; do
            IFS='|' read -r PRI RANK SEC LABEL STATUS <<< "$ISSUE"
            local SEEN2=0
            for S in "${TOP_SECS[@]}"; do [ "$S" = "$SEC" ] && SEEN2=1; done
            [ "$SEEN2" -eq 0 ] && TOP_SECS+=("$SEC")
            [ "${#TOP_SECS[@]}" -ge 2 ] && break
        done
    fi
    if [ "${#TOP_SECS[@]}" -gt 0 ]; then
        TOP_TEXT="$(_mr_join_sections "${TOP_SECS[@]}")"
    fi
    [ -z "$TOP_TEXT" ] && TOP_TEXT="multiple operational areas"

    if [ "$_MR_CRIT" -gt 0 ]; then
        NARRATIVE="The assessment covered ${_MR_TOTAL} controls across ${AREAS} operational areas. ${_MR_CRIT} controls require action and ${_MR_WARN} need review; the highest-impact gaps are in ${TOP_TEXT}."
    elif [ "$_MR_WARN" -gt 0 ]; then
        NARRATIVE="The assessment covered ${_MR_TOTAL} controls across ${AREAS} operational areas. No critical gaps were found, but ${_MR_WARN} controls are worth reviewing; most findings are in ${TOP_TEXT}."
    else
        NARRATIVE="The assessment covered ${_MR_TOTAL} controls across ${AREAS} operational areas. All evaluated controls passed; no corrective action is required at this review."
    fi

    _mr_section_title "01" "Executive overview" "What the assessment found and where to focus first."
    _mr_paragraph "$MR_MARGIN" "$_MR_Y" "$NARRATIVE" 84 "F1" 9.4 "$MR_C_TEXT" 13 3
    _MR_Y=$((_MR_LAST_Y - 10))

    _mr_text "$MR_MARGIN" "$_MR_Y" "CONTROL DISTRIBUTION" "F2" 6.6 "$MR_C_MUTED"
    _MR_Y=$((_MR_Y - 14))

    local BAR_W="$MR_CONTENT_W"
    local BAR_H=8
    local BAR_X="$MR_MARGIN"
    local BAR_Y=$((_MR_Y - BAR_H))
    local TOTAL_ALL=$((_MR_PASS + _MR_WARN + _MR_CRIT + _MR_INFO + _MR_NA))
    _mr_round_rect "$BAR_X" "$BAR_Y" "$BAR_W" "$BAR_H" 4 "0.890 0.910 0.940"
    if [ "$TOTAL_ALL" -gt 0 ]; then
        local PW WW CW IW NW PX="$BAR_X"
        PW=$(awk -v w="$BAR_W" -v n="$_MR_PASS" -v t="$TOTAL_ALL" 'BEGIN{printf "%d", (w*n/t)}')
        WW=$(awk -v w="$BAR_W" -v n="$_MR_WARN" -v t="$TOTAL_ALL" 'BEGIN{printf "%d", (w*n/t)}')
        CW=$(awk -v w="$BAR_W" -v n="$_MR_CRIT" -v t="$TOTAL_ALL" 'BEGIN{printf "%d", (w*n/t)}')
        IW=$(awk -v w="$BAR_W" -v n="$_MR_INFO" -v t="$TOTAL_ALL" 'BEGIN{printf "%d", (w*n/t)}')
        NW=$((BAR_W - PW - WW - CW - IW))
        [ "$PW" -gt 0 ] && _mr_rect "$PX" "$BAR_Y" "$PW" "$BAR_H" "$MR_C_GREEN"
        PX=$((PX + PW))
        [ "$WW" -gt 0 ] && _mr_rect "$PX" "$BAR_Y" "$WW" "$BAR_H" "$MR_C_AMBER"
        PX=$((PX + WW))
        [ "$CW" -gt 0 ] && _mr_rect "$PX" "$BAR_Y" "$CW" "$BAR_H" "$MR_C_ROSE"
        PX=$((PX + CW))
        [ "$IW" -gt 0 ] && _mr_rect "$PX" "$BAR_Y" "$IW" "$BAR_H" "$MR_C_VIOLET"
        PX=$((PX + IW))
        [ "$NW" -gt 0 ] && _mr_rect "$PX" "$BAR_Y" "$NW" "$BAR_H" "$MR_C_SLATE"
    fi
    _MR_Y=$((BAR_Y - 16))

    _mr_legend_item "$MR_MARGIN" "$_MR_Y" PASS "Healthy" "$_MR_PASS"
    _mr_legend_item "$((MR_MARGIN + 104))" "$_MR_Y" WARN "Review" "$_MR_WARN"
    _mr_legend_item "$((MR_MARGIN + 208))" "$_MR_Y" CRITICAL "Action" "$_MR_CRIT"
    _mr_legend_item "$((MR_MARGIN + 312))" "$_MR_Y" INFO "Info" "$_MR_INFO"
    _mr_legend_item "$((MR_MARGIN + 416))" "$_MR_Y" NA "N/A" "$_MR_NA"
    _MR_Y=$((_MR_Y - 30))

    local LEFT_W=316 RIGHT_W=190 GAP=18 RIGHT_X=$((MR_MARGIN + 316 + 18))
    _mr_text "$MR_MARGIN" "$_MR_Y" "PRIORITY ACTIONS" "F2" 6.6 "$MR_C_MUTED"
    _mr_text "$RIGHT_X" "$_MR_Y" "KEY SIGNALS" "F2" 6.6 "$MR_C_MUTED"
    _MR_Y=$((_MR_Y - 12))

    local CARD_Y=$((_MR_Y - 64))
    local N=0
    if [ "${#_MR_SORTED_ISSUES[@]}" -gt 0 ]; then
        for ISSUE in "${_MR_SORTED_ISSUES[@]}"; do
            N=$((N + 1))
            [ "$N" -gt 4 ] && break
            IFS='|' read -r PRI RANK SEC LABEL STATUS <<< "$ISSUE"
            _mr_card "$MR_MARGIN" "$CARD_Y" "$LEFT_W" 64 6
            _mr_rect "$MR_MARGIN" "$CARD_Y" 3 64 "$(_mr_status_color "$STATUS")"
            _mr_circle "$((MR_MARGIN + 18))" "$((CARD_Y + 48))" 4 "$(_mr_status_color "$STATUS")"
            _mr_text_trunc "$((MR_MARGIN + 28))" "$((CARD_Y + 44))" "$(_mr_display_label "$LABEL")" "F2" 8.8 "$MR_C_TEXT" 42
            local CHIP_W=54
            local CHIP_X=$((MR_MARGIN + LEFT_W - CHIP_W - 10))
            _mr_round_rect "$CHIP_X" "$((CARD_Y + 42))" "$CHIP_W" 14 7 "$(_mr_status_fill "$STATUS")"
            _mr_text_center "$((CHIP_X + CHIP_W / 2))" "$((CARD_Y + 45))" "$(_mr_status_word "$STATUS")" "F2" 6.2 "$(_mr_status_text_color "$STATUS")"
            _mr_text_trunc "$((MR_MARGIN + 12))" "$((CARD_Y + 28))" "$SEC" "F1" 6.3 "$MR_C_MUTED" 52
            _mr_text_trunc "$((MR_MARGIN + 12))" "$((CARD_Y + 13))" "$(_mr_action_text "$LABEL" "$SEC")" "F1" 7.1 "$MR_C_TEXT" 72
            CARD_Y=$((CARD_Y - 72))
        done
    else
        _mr_card "$MR_MARGIN" "$CARD_Y" "$LEFT_W" 64 6
        _mr_circle "$((MR_MARGIN + 18))" "$((CARD_Y + 32))" 5 "$MR_C_GREEN"
        _mr_text "$((MR_MARGIN + 30))" "$((CARD_Y + 36))" "No corrective actions required" "F2" 9 "$MR_C_TEXT"
        _mr_text "$((MR_MARGIN + 30))" "$((CARD_Y + 22))" "All evaluated controls passed at this review." "F1" 7.2 "$MR_C_MUTED"
    fi

    local SIGNAL_Y=$((_MR_Y - 62))
    local -a SIG_LABELS=("BACKUP & RECOVERY" "TRANSPORT SECURITY" "MAIL FLOW & DNS" "OS & PATCHING")
    local -a SIG_KEYS=("backup" "tls" "mail_flow" "os_update")
    local K
    for K in 0 1 2 3; do
        local SK="${SIG_KEYS[$K]}"
        local SRES="${HEALTH[$SK]:-skip}"
        [ "$SRES" = "critical" ] && SRES="fail"
        local SCOLOR SSTATUS
        SCOLOR="$(_mr_status_color "$SRES")"
        SSTATUS="$(_mr_status_word "$SRES")"
        _mr_card "$RIGHT_X" "$SIGNAL_Y" "$RIGHT_W" 58 6
        _mr_circle "$((RIGHT_X + 12))" "$((SIGNAL_Y + 42))" 4 "$SCOLOR"
        _mr_text "$((RIGHT_X + 22))" "$((SIGNAL_Y + 39))" "${SIG_LABELS[$K]}" "F1" 5.9 "$MR_C_MUTED"
        _mr_text "$((RIGHT_X + 12))" "$((SIGNAL_Y + 26))" "$SSTATUS" "F2" 8.6 "$MR_C_TEXT"
        _mr_paragraph "$((RIGHT_X + 12))" "$((SIGNAL_Y + 15))" "${HEALTH_MSG[$SK]:-No data returned}" 38 "F1" 5.8 "$MR_C_MUTED" 7.2 2
        SIGNAL_Y=$((SIGNAL_Y - 66))
    done

    local TAKEAWAY
    if [ "$_MR_CRIT" -gt 0 ]; then
        TAKEAWAY="The platform is largely healthy, but the material risk sits in ${TOP_TEXT}. Resolve those actions first, then re-run the assessment to confirm closure."
    elif [ "$_MR_WARN" -gt 0 ]; then
        TAKEAWAY="The platform is broadly healthy. The review items are not urgent, but closing them will reduce avoidable operational risk."
    else
        TAKEAWAY="All evaluated controls passed. Maintain the current configuration and repeat the assessment at the next scheduled review."
    fi
    _mr_card "$MR_MARGIN" 150 "$MR_CONTENT_W" 72 7
    _mr_rect "$MR_MARGIN" 150 3 72 "$MR_C_TEAL"
    _mr_text "$((MR_MARGIN + 16))" 208 "MANAGEMENT TAKEAWAY" "F2" 6.6 "$MR_C_TEAL_DARK"
    _mr_paragraph "$((MR_MARGIN + 16))" 194 "$TAKEAWAY" 96 "F1" 8.2 "$MR_C_TEXT" 10 3
}

_mr_render_control_areas() {
    _mr_section_title "02" "Control areas" "How each operational area performed across the full checklist."
    local COL_W=254 GAP=16 CARD_H=60 ROW_GAP=8
    local COL=0 ROW_Y="$_MR_Y" X SEC STATUS TOTAL SECN COLOR
    for SEC in "${_MR_SECTION_ORDER[@]}"; do
        if [ "$COL" -eq 0 ]; then
            _mr_ensure "$((CARD_H + ROW_GAP))"
            ROW_Y="$_MR_Y"
        fi
        X=$((MR_MARGIN + COL * (COL_W + GAP)))
        STATUS="$(_mr_section_status "$SEC")"
        COLOR="$(_mr_status_color "$STATUS")"
        _mr_card "$X" "$((ROW_Y - CARD_H))" "$COL_W" "$CARD_H" 6
        _mr_circle "$((X + 14))" "$((ROW_Y - 16))" 4 "$COLOR"
        _mr_text_trunc "$((X + 25))" "$((ROW_Y - 19))" "$SEC" "F2" 8.2 "$MR_C_TEXT" 34
        _mr_text_right "$((X + COL_W - 10))" "$((ROW_Y - 19))" "$(_mr_status_word "$STATUS")" "F2" 6.4 "$COLOR"
        if [ "$STATUS" = "NA" ]; then
            _mr_text "$((X + 14))" "$((ROW_Y - 35))" "No applicable controls" "F1" 6.1 "$MR_C_MUTED"
        else
            local COUNT_LINE="${_MR_SEC_PASS[$SEC]:-0} healthy  |  ${_MR_SEC_WARN[$SEC]:-0} review  |  ${_MR_SEC_CRIT[$SEC]:-0} action"
            [ "${_MR_SEC_INFO[$SEC]:-0}" -gt 0 ] && COUNT_LINE="$COUNT_LINE  |  ${_MR_SEC_INFO[$SEC]:-0} info"
            _mr_text "$((X + 14))" "$((ROW_Y - 35))" "$COUNT_LINE" "F1" 6.0 "$MR_C_MUTED"
            TOTAL=$(( ${_MR_SEC_PASS[$SEC]:-0} + ${_MR_SEC_WARN[$SEC]:-0} + ${_MR_SEC_CRIT[$SEC]:-0} + ${_MR_SEC_INFO[$SEC]:-0} ))
            _mr_rect "$((X + 14))" "$((ROW_Y - 50))" "$((COL_W - 28))" 4 "0.900 0.920 0.950"
            if [ "$TOTAL" -gt 0 ]; then
                local TRACK_W=$((COL_W - 28))
                local PW WW CW IW PX=$((X + 14))
                PW=$(awk -v w="$TRACK_W" -v n="${_MR_SEC_PASS[$SEC]:-0}" -v t="$TOTAL" 'BEGIN{printf "%d", (w*n/t)}')
                WW=$(awk -v w="$TRACK_W" -v n="${_MR_SEC_WARN[$SEC]:-0}" -v t="$TOTAL" 'BEGIN{printf "%d", (w*n/t)}')
                CW=$(awk -v w="$TRACK_W" -v n="${_MR_SEC_CRIT[$SEC]:-0}" -v t="$TOTAL" 'BEGIN{printf "%d", (w*n/t)}')
                IW=$((TRACK_W - PW - WW - CW))
                [ "$PW" -gt 0 ] && _mr_rect "$PX" "$((ROW_Y - 50))" "$PW" 4 "$MR_C_GREEN"
                PX=$((PX + PW))
                [ "$WW" -gt 0 ] && _mr_rect "$PX" "$((ROW_Y - 50))" "$WW" 4 "$MR_C_AMBER"
                PX=$((PX + WW))
                [ "$CW" -gt 0 ] && _mr_rect "$PX" "$((ROW_Y - 50))" "$CW" 4 "$MR_C_ROSE"
                PX=$((PX + CW))
                [ "$IW" -gt 0 ] && _mr_rect "$PX" "$((ROW_Y - 50))" "$IW" 4 "$MR_C_VIOLET"
            fi
        fi
        if [ "$COL" -eq 1 ]; then
            COL=0
            _MR_Y=$((ROW_Y - CARD_H - ROW_GAP))
        else
            COL=1
        fi
    done
    if [ "$COL" -eq 1 ]; then
        _MR_Y=$((ROW_Y - CARD_H - ROW_GAP))
    fi

    _mr_ensure 84
    _mr_text "$MR_MARGIN" "$_MR_Y" "STATUS KEY" "F2" 6.6 "$MR_C_MUTED"
    _MR_Y=$((_MR_Y - 12))
    local LEG_Y=$((_MR_Y - 58))
    _mr_card "$MR_MARGIN" "$LEG_Y" "$MR_CONTENT_W" 58 6
    local -a LEG_STATUS=("PASS" "WARN" "CRITICAL" "INFO")
    local -a LEG_TITLE=("Healthy" "Review" "Action" "Info / N/A")
    local -a LEG_DESC=("Meets the baseline" "Worth reviewing" "Needs remediation" "Context only")
    local LI LX
    for LI in 0 1 2 3; do
        LX=$((MR_MARGIN + 16 + LI * 126))
        _mr_circle "$((LX + 4))" "$((LEG_Y + 36))" 4 "$(_mr_status_color "${LEG_STATUS[$LI]}")"
        _mr_text "$((LX + 14))" "$((LEG_Y + 33))" "${LEG_TITLE[$LI]}" "F2" 7.6 "$MR_C_TEXT"
        _mr_text "$((LX + 14))" "$((LEG_Y + 20))" "${LEG_DESC[$LI]}" "F1" 6.4 "$MR_C_MUTED"
    done
    _MR_Y=$((LEG_Y - 8))
}

_mr_render_actions() {
    _mr_section_title "03" "Recommended actions" "Ordered by operational impact. The technical report lists every finding."
    local N=0 ISSUE PRI RANK SEC LABEL STATUS CARD_H=56 CARD_Y
    if [ "${#_MR_SORTED_ISSUES[@]}" -eq 0 ]; then
        _mr_card "$MR_MARGIN" "$((_MR_Y - 64))" "$MR_CONTENT_W" 64 6
        _mr_circle "$((MR_MARGIN + 22))" "$((_MR_Y - 32))" 5 "$MR_C_GREEN"
        _mr_text "$((MR_MARGIN + 36))" "$((_MR_Y - 28))" "No corrective actions are required" "F2" 10 "$MR_C_TEXT"
        _mr_text "$((MR_MARGIN + 36))" "$((_MR_Y - 43))" "All evaluated controls passed at this review." "F1" 7.4 "$MR_C_MUTED"
        _MR_Y=$((_MR_Y - 78))
    else
        for ISSUE in "${_MR_SORTED_ISSUES[@]}"; do
            N=$((N + 1))
            [ "$N" -gt 6 ] && break
            IFS='|' read -r PRI RANK SEC LABEL STATUS <<< "$ISSUE"
            _mr_ensure "$((CARD_H + 8))"
            CARD_Y=$((_MR_Y - CARD_H))
            _mr_card "$MR_MARGIN" "$CARD_Y" "$MR_CONTENT_W" "$CARD_H" 6
            _mr_rect "$MR_MARGIN" "$CARD_Y" 3 "$CARD_H" "$(_mr_status_color "$STATUS")"
            _mr_text "$((MR_MARGIN + 12))" "$((CARD_Y + 38))" "$(printf '%02d' "$N")" "F2" 7.2 "$MR_C_TEAL_DARK"
            _mr_text_trunc "$((MR_MARGIN + 38))" "$((CARD_Y + 36))" "$(_mr_display_label "$LABEL")" "F2" 8.8 "$MR_C_TEXT" 52
            local CHIP_W=54
            local CHIP_X=$((MR_RIGHT - CHIP_W - 10))
            _mr_round_rect "$CHIP_X" "$((CARD_Y + 34))" "$CHIP_W" 14 7 "$(_mr_status_fill "$STATUS")"
            _mr_text_center "$((CHIP_X + CHIP_W / 2))" "$((CARD_Y + 37))" "$(_mr_status_word "$STATUS")" "F2" 6.2 "$(_mr_status_text_color "$STATUS")"
            _mr_text_trunc "$((MR_MARGIN + 38))" "$((CARD_Y + 23))" "$SEC" "F1" 6.3 "$MR_C_MUTED" 60
            _mr_text_trunc "$((MR_MARGIN + 38))" "$((CARD_Y + 9))" "$(_mr_action_text "$LABEL" "$SEC")" "F1" 7.1 "$MR_C_TEXT" 84
            _MR_Y=$((CARD_Y - 8))
        done
        _MR_Y=$((_MR_Y - 14))
    fi

    if [ "$_MR_Y" -gt 140 ]; then
        _mr_text "$MR_MARGIN" "$_MR_Y" "ASSESSMENT SCOPE" "F2" 6.6 "$MR_C_MUTED"
        _MR_Y=$((_MR_Y - 12))
        local PANEL_Y=$((_MR_Y - 58))
        _mr_card "$MR_MARGIN" "$PANEL_Y" "$MR_CONTENT_W" 58 6
        local COL1=$((MR_MARGIN + 14)) COL2=$((MR_MARGIN + 182)) COL3=$((MR_MARGIN + 350))
        _mr_text "$COL1" "$((PANEL_Y + 36))" "STANDARD" "F1" 5.8 "$MR_C_MUTED"
        _mr_text "$COL1" "$((PANEL_Y + 20))" "IceWarp CheckList v${MR_CHECKLIST_VERSION}" "F2" 7.8 "$MR_C_TEXT"
        _mr_text "$COL2" "$((PANEL_Y + 36))" "EVIDENCE" "F1" 5.8 "$MR_C_MUTED"
        _mr_text "$COL2" "$((PANEL_Y + 20))" "Live collector data" "F2" 7.8 "$MR_C_TEXT"
        _mr_text "$COL3" "$((PANEL_Y + 36))" "NEXT REVIEW" "F1" 5.8 "$MR_C_MUTED"
        _mr_text "$COL3" "$((PANEL_Y + 20))" "Next scheduled assessment" "F2" 7.8 "$MR_C_TEXT"

        if [ "$PANEL_Y" -gt 92 ]; then
            _mr_text "$MR_MARGIN" "$((PANEL_Y - 18))" "NEXT STEP" "F2" 6.4 "$MR_C_TEAL_DARK"
            _mr_paragraph "$MR_MARGIN" "$((PANEL_Y - 32))" "Review the action list with the service owner, schedule the remediation window, then re-run the assessment to confirm closure." 100 "F1" 7.8 "$MR_C_TEXT" 10 2
        fi
    fi
}

# =============================================================================
# SECTION 11: MAIN BUILDER
# =============================================================================

build_management_pdf() {
    local OUT_PDF="${OUTPUT_MANAGEMENT_PDF:-${PROJECT_ROOT}/output/management_report.pdf}"
    _MR_PAGES=()
    _MR_CUR=""
    _MR_PAGE_NO=0
    _MR_FOOTER=0
    _MR_Y=$MR_TOP_Y

    # Evaluate first so the cover, score and priority list use final counts.
    _mr_render_checklist

    local SCORED=$((_MR_PASS + _MR_WARN + _MR_CRIT))
    _MR_SCORE=0
    [ "$SCORED" -gt 0 ] && _MR_SCORE=$((_MR_PASS * 100 / SCORED))
    if [ "$_MR_CRIT" -gt 0 ]; then
        _MR_OVERALL="fail"
    elif [ "$_MR_WARN" -gt 0 ]; then
        _MR_OVERALL="warn"
    else
        _MR_OVERALL="pass"
    fi

    _MR_SORTED_ISSUES=()
    if [ "${#_MR_ISSUES[@]}" -gt 0 ]; then
        local ISSUE_LINE
        while IFS= read -r ISSUE_LINE; do
            [ -n "$ISSUE_LINE" ] && _MR_SORTED_ISSUES+=("$ISSUE_LINE")
        done < <(printf '%s\n' "${_MR_ISSUES[@]}" | sort -t'|' -k1,1n -k2,2n)
    fi

    _mr_cover_letter
    _mr_executive_overview
    _mr_new_page
    _mr_render_control_areas
    _mr_new_page
    _mr_render_actions

    _mr_finish
    _mr_write_file "$OUT_PDF"
}
