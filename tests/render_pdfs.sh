#!/bin/bash
# Render both PDFs from a sample DATA[] fixture and extract their text, so the
# output can be inspected for truncated or overlapping text and cross-checked
# against health.json.
#
#   ./tests/render_pdfs.sh [fixtures/healthy.dat]
#
# Needs: bash, awk, date, pdftotext (poppler-utils). Produces
#   tests/output/report.txt            extracted text of the technical report
#   tests/output/management.txt         extracted text of the management report
#   tests/output/health.json            the JSON the PDFs were built from

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/tests/output"
FIXTURE="${1:-$ROOT/tests/fixtures/healthy.dat}"

mkdir -p "$OUT_DIR"

# Stubs so the libraries load on a machine with no IceWarp tool.sh.
IW_TOOL=""
iw_tool_get() { printf ''; }
iw_tool_get_multiline() { printf ''; }
iw_get() { printf ''; }
iw_get_domain() { printf ''; }
iw_list_domains() { return 0; }

source "$ROOT/lib/common.sh"
source "$ROOT/lib/health.sh"
source "$ROOT/lib/json.sh"
source "$ROOT/lib/pdf.sh"
source "$ROOT/lib/management_report.sh"

# --- Load the fixture ------------------------------------------------------
while IFS= read -r LINE || [ -n "$LINE" ]; do
    LINE="${LINE%%#*}"
    [ -z "${LINE//[[:space:]]/}" ] && continue
    KEY="${LINE%% *}"
    VAL="${LINE#* }"
    DATA["$KEY"]="$VAL"
done < "$FIXTURE"

# --- Evaluate and export ---------------------------------------------------
evaluate_health
OUTPUT_JSON="$OUT_DIR/health.json"
build_json
build_json_v2 || true

# --- Render ----------------------------------------------------------------
OUTPUT_PDF="$OUT_DIR/report.pdf"
build_pdf
OUTPUT_MANAGEMENT_PDF="$OUT_DIR/management_report.pdf"
build_management_pdf

# --- Extract text ----------------------------------------------------------
if command -v pdftotext >/dev/null 2>&1; then
    pdftotext -layout "$OUT_DIR/report.pdf" "$OUT_DIR/report.txt"
    pdftotext -layout "$OUT_DIR/management_report.pdf" "$OUT_DIR/management.txt"
    echo "[INFO] extracted text -> $OUT_DIR/report.txt, $OUT_DIR/management.txt"
else
    echo "[WARN] pdftotext not installed; text extraction skipped" >&2
fi

echo "[INFO] rendered $OUT_DIR/report.pdf and $OUT_DIR/management_report.pdf"
echo "[INFO] JSON -> $OUT_DIR/health.json"