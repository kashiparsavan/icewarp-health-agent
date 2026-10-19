#!/bin/bash
# ============================================================
# IceWarp Health Agent - Entry Point (Final Fixed)
# ============================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT

CONFIG_DIR="${PROJECT_ROOT}/config"
LIB_DIR="${PROJECT_ROOT}/lib"
COLLECTOR_DIR="${PROJECT_ROOT}/collectors"
OUTPUT_DIR="${PROJECT_ROOT}/output"
LOG_DIR="${PROJECT_ROOT}/logs"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$LOG_DIR"

# ---------- Source libraries in correct order ----------
[ -f "$LIB_DIR/common.sh" ] && source "$LIB_DIR/common.sh"
[ -f "$LIB_DIR/health.sh" ] && source "$LIB_DIR/health.sh"
[ -f "$LIB_DIR/pdf.sh" ] && source "$LIB_DIR/pdf.sh"
[ -f "$LIB_DIR/json.sh" ] && source "$LIB_DIR/json.sh"
[ -f "$LIB_DIR/management_report.sh" ] && source "$LIB_DIR/management_report.sh"
[ -f "$LIB_DIR/transport.sh" ] && source "$LIB_DIR/transport.sh"
[ -f "$LIB_DIR/configurator.sh" ] && source "$LIB_DIR/configurator.sh"

# ---------- Source config files ----------
for CFG in "$CONFIG_DIR"/*.conf; do
    [ -f "$CFG" ] || continue
    case "$(basename "$CFG")" in
        agent.conf|icewarp.conf) source "$CFG" ;;
    esac
done

# ---------- Read Version from VERSION file ----------
if [ -f "${PROJECT_ROOT}/VERSION" ]; then
    AGENT_VERSION="$(cat "${PROJECT_ROOT}/VERSION" | tr -d '[:space:]')"
else
    AGENT_VERSION="unknown"
fi

# ---------- Help Function ----------
show_help() {
    echo "IceWarp Health Agent v${AGENT_VERSION}"
    echo ""
    echo "Usage: ./agent.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --report                Run collectors and print summary to console"
    echo "  --list                  List all available collectors"
    echo "  --config                Run configurator (dry-run, no changes applied)"
    echo "  --config --apply        Apply recommended settings to IceWarp"
    echo "  --only=<filter>         Run only collectors matching the filter (comma-separated)"
    echo "  --technician=\"Name\"     Override technician name in reports"
    echo "  --company=\"Name\"        Override company name in reports"
    echo "  --no-update             Skip OS update check"
    echo "  --help                  Show this help message"
    echo ""
    exit 0
}

# ---------- Parse arguments ----------
MODE="run"
ARG_TECHNICIAN=""
ARG_COMPANY=""
COLLECTOR_FILTER=""

for ARG in "$@"; do
    case "$ARG" in
        --help) show_help ;;
        --config) MODE="--config" ;;
        --list) MODE="--list" ;;
        --report) MODE="--report" ;;
        --only=*) COLLECTOR_FILTER="${ARG#--only=}" ;;
        --company=*) ARG_COMPANY="${ARG#--company=}" ;;
        --technician=*) ARG_TECHNICIAN="${ARG#--technician=}" ;;
        --no-update) ;;
    esac
done

if [ "$MODE" = "--list" ]; then
    list_collectors
    exit 0
fi

if [ "$MODE" = "--config" ]; then
    configurator_parse_args "$@"
    configurator_run
    exit 0
fi

# ---------- Acquire Lock ----------
acquire_lock
trap 'release_lock' EXIT

# ---------- Initialize ----------
agent_init

if [ -n "$ARG_TECHNICIAN" ]; then
    DATA["general.technician"]="$ARG_TECHNICIAN"
else
    DATA["general.technician"]="Not Specified"
fi

# ---------- Run all collectors ----------
echo "[INFO] Running all collectors..."

while IFS= read -r COLLECTOR; do
    if [ -n "$COLLECTOR_FILTER" ]; then
        MATCH=0
        IFS=',' read -ra FILTERS <<< "$COLLECTOR_FILTER"
        for F in "${FILTERS[@]}"; do
            [[ "$COLLECTOR" == *"$F"* ]] && MATCH=1
        done
        [ "$MATCH" -eq 0 ] && continue
    fi

    echo "[RUN ] ${COLLECTOR#$PROJECT_ROOT/}"
    run_collector "$COLLECTOR"
done < <(find "$COLLECTOR_DIR" -type f -name "*.sh" | sort)

# ---------- Post-processing ----------
if [ -n "$ARG_COMPANY" ]; then
    DATA["general.company"]="$ARG_COMPANY"
elif [ -z "${DATA[general.company]:-}" ]; then
    DATA["general.company"]="${DATA[domain.primary.name]:-${DATA[agent.hostname]:-Unknown Host}}"
fi

echo "[INFO] Evaluating health..."
evaluate_health

echo "[INFO] Building JSON..."
build_json

echo "[INFO] Sending JSON to monitoring server (if enabled)..."
send_json

echo "[INFO] Building PDF..."
build_pdf

echo "[INFO] Building management report..."
build_management_pdf

if [ "$MODE" = "--report" ]; then
    print_report
fi

echo "[INFO] Agent finished successfully."
exit 0
