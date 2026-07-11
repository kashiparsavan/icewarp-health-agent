#!/bin/bash

###############################################################################
#
# PDF Report Writer (M5)
#
# Deliberately dependency-free: this agent runs unattended on customer
# production IceWarp mail servers, and we can't assume python3/reportlab/
# wkhtmltopdf/pandoc are installed there (and won't have internet access to
# install them). So the report is written directly in the PDF file format -
# a well-known technique for simple single-column monospace text reports -
# using only bash + printf + wc. No new runtime dependency is introduced.
#
# Produces one PDF with a Health Summary section followed by the full raw
# data table, paginated automatically.
#
###############################################################################

PDF_PAGE_WIDTH=612
PDF_PAGE_HEIGHT=792
PDF_MARGIN_LEFT=40
PDF_MARGIN_TOP=760
PDF_LINE_HEIGHT=12
PDF_FONT_SIZE=9
PDF_LINES_PER_PAGE=58
PDF_MAX_LINE_CHARS=112   # keeps text inside the printable width at 9pt Helvetica

_pdf_escape() {
    local S="$1"
    # Strip anything outside printable ASCII to keep the PDF string literal
    # syntax simple and safe (no encoding edge cases to worry about).
    S="$(printf '%s' "$S" | LC_ALL=C tr -c '\40-\176' '?')"
    S="${S//\\/\\\\}"
    S="${S//(/\\(}"
    S="${S//)/\\)}"
    if [ "${#S}" -gt "$PDF_MAX_LINE_CHARS" ]; then
        S="${S:0:$((PDF_MAX_LINE_CHARS-3))}..."
    fi
    printf '%s' "$S"
}

# Builds one content stream (a page worth of text) from an array of lines.
_pdf_build_stream() {
    local -n LINES_REF=$1
    local OUT="BT /F1 ${PDF_FONT_SIZE} Tf ${PDF_LINE_HEIGHT} TL ${PDF_MARGIN_LEFT} ${PDF_MARGIN_TOP} Td"$'\n'
    local FIRST=1
    local LINE ESCAPED
    for LINE in "${LINES_REF[@]}"; do
        ESCAPED="$(_pdf_escape "$LINE")"
        if [ "$FIRST" -eq 1 ]; then
            OUT="${OUT}(${ESCAPED}) Tj"$'\n'
            FIRST=0
        else
            OUT="${OUT}T* (${ESCAPED}) Tj"$'\n'
        fi
    done
    OUT="${OUT}ET"
    printf '%s' "$OUT"
}

# Records the byte offset of object $1 (current EOF position) then appends
# the object's raw bytes to the output file.
_pdf_obj() {
    local NUM="$1"; shift
    PDF_OFFSETS[$NUM]="$(wc -c < "$PDF_OUT_FILE")"
    printf '%s' "$1" >> "$PDF_OUT_FILE"
}

_pdf_write_file() {
    local OUT_PDF="$1"
    local -n PAGES_REF=$2
    local P="${#PAGES_REF[@]}"

    if [ "$P" -eq 0 ]; then
        echo "[WARN] build_pdf: nothing to render, skipping PDF output" >&2
        return 1
    fi

    local FONT_OBJ=$((3 + 2*P))
    declare -Ag PDF_OFFSETS=()
    PDF_OUT_FILE="$OUT_PDF"

    : > "$OUT_PDF"
    printf '%%PDF-1.4\n' >> "$OUT_PDF"

    _pdf_obj 1 "1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
"

    local KIDS="" i
    for ((i=1; i<=P; i++)); do
        KIDS="${KIDS}$((2+i)) 0 R "
    done
    _pdf_obj 2 "2 0 obj
<< /Type /Pages /Kids [ ${KIDS}] /Count ${P} >>
endobj
"

    for ((i=1; i<=P; i++)); do
        local PAGE_NUM=$((2+i))
        local CONTENT_NUM=$((2+P+i))
        local STREAM="${PAGES_REF[$((i-1))]}"
        local STREAM_LEN
        STREAM_LEN="$(printf '%s' "$STREAM" | wc -c)"

        _pdf_obj "$PAGE_NUM" "${PAGE_NUM} 0 obj
<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 ${FONT_OBJ} 0 R >> >> /MediaBox [0 0 ${PDF_PAGE_WIDTH} ${PDF_PAGE_HEIGHT}] /Contents ${CONTENT_NUM} 0 R >>
endobj
"
        _pdf_obj "$CONTENT_NUM" "${CONTENT_NUM} 0 obj
<< /Length ${STREAM_LEN} >>
stream
${STREAM}
endstream
endobj
"
    done

    _pdf_obj "$FONT_OBJ" "${FONT_OBJ} 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
"

    local XREF_START
    XREF_START="$(wc -c < "$OUT_PDF")"
    local TOTAL_OBJS=$((FONT_OBJ + 1))

    {
        printf 'xref\n0 %d\n' "$TOTAL_OBJS"
        printf '0000000000 65535 f \n'
        local n
        for ((n=1; n<=FONT_OBJ; n++)); do
            printf '%010d 00000 n \n' "${PDF_OFFSETS[$n]}"
        done
        printf 'trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n' "$TOTAL_OBJS" "$XREF_START"
    } >> "$OUT_PDF"

    echo "[INFO] PDF report written: $OUT_PDF ($(wc -c < "$OUT_PDF") bytes, ${P} page(s))"
}

build_pdf() {

    local OUT_PDF="${OUTPUT_PDF:-${PROJECT_ROOT}/output/report.pdf}"
    local -a ALL_LINES=()

    ALL_LINES+=("IceWarp Health Check Report")
    ALL_LINES+=("Host: ${DATA[agent.hostname]:-unknown}   Generated: ${DATA[agent.time]:-unknown}   Agent v${DATA[agent.version]:-unknown}")
    ALL_LINES+=("")
    ALL_LINES+=("=== Health Summary ===")
    ALL_LINES+=("Overall: ${DATA[health.summary.overall]:-n/a}   Failed: ${DATA[health.summary.failed]:-0}   Warnings: ${DATA[health.summary.warnings]:-0}   Checked: ${DATA[health.summary.total_checks]:-0}")
    ALL_LINES+=("")

    local K
    if [ "${#HEALTH[@]}" -gt 0 ]; then
        for K in $(printf '%s\n' "${!HEALTH[@]}" | sort); do
            ALL_LINES+=("$(printf '[%-4s] %-20s %s' "${HEALTH[$K]}" "$K" "${HEALTH_MSG[$K]:-}")")
        done
    else
        ALL_LINES+=("(health rules did not run)")
    fi

    ALL_LINES+=("")
    ALL_LINES+=("=== Collector Status ===")
    local FAILED_COLLECTORS=0
    for K in $(printf '%s\n' "${!STATUS[@]}" | sort); do
        [ "${STATUS[$K]}" = "ok" ] && continue
        FAILED_COLLECTORS=$((FAILED_COLLECTORS+1))
        ALL_LINES+=("$(printf '[%s] %-30s %s' "${STATUS[$K]}" "$K" "${STATUS_MSG[$K]:-}")")
    done
    [ "$FAILED_COLLECTORS" -eq 0 ] && ALL_LINES+=("All collectors ran OK")

    ALL_LINES+=("")
    ALL_LINES+=("=== Collected Data (${#DATA[@]} keys) ===")
    ALL_LINES+=("")

    for K in $(printf '%s\n' "${!DATA[@]}" | sort); do
        ALL_LINES+=("$(printf '%-42s %s' "$K" "${DATA[$K]}")")
    done

    local -a PAGES_CONTENT=()
    local -a CUR=()
    local COUNT=0 LINE
    for LINE in "${ALL_LINES[@]}"; do
        CUR+=("$LINE")
        COUNT=$((COUNT+1))
        if [ "$COUNT" -ge "$PDF_LINES_PER_PAGE" ]; then
            PAGES_CONTENT+=("$(_pdf_build_stream CUR)")
            CUR=()
            COUNT=0
        fi
    done
    if [ "${#CUR[@]}" -gt 0 ]; then
        PAGES_CONTENT+=("$(_pdf_build_stream CUR)")
    fi

    _pdf_write_file "$OUT_PDF" PAGES_CONTENT
}
