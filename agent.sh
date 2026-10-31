#!/bin/bash
# ============================================================
# IceWarp Health Agent - Entry Point
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

# ---------- Source config files first ----------
# The auto-updater needs AUTO_UPDATE_* settings before it runs.
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
    echo "  --check-update          Check for a newer git revision, then exit"
    echo "  --no-auto-update        Skip the automatic git update for this run"
    echo "  --auto-update           Force an update check even if disabled in config"
    echo "  --no-update             Deprecated no-op (use --no-auto-update)"
    echo "  --help                  Show this help message"
    echo ""
    exit 0
}

# ---------- Parse arguments ----------
MODE="run"
ARG_TECHNICIAN=""
ARG_COMPANY=""
COLLECTOR_FILTER=""
AUTO_UPDATE_CHECK_ONLY=0
AUTO_UPDATE_DISABLED=0

for ARG in "$@"; do
    case "$ARG" in
        --help) show_help ;;
        --config) MODE="--config" ;;
        --list) MODE="--list" ;;
        --report) MODE="--report" ;;
        --only=*) COLLECTOR_FILTER="${ARG#--only=}" ;;
        --company=*) ARG_COMPANY="${ARG#--company=}" ;;
        --technician=*) ARG_TECHNICIAN="${ARG#--technician=}" ;;
        --check-update) AUTO_UPDATE_CHECK_ONLY=1 ;;
        --no-auto-update) AUTO_UPDATE_DISABLED=1; AUTO_UPDATE_ENABLED=0 ;;
        --auto-update) AUTO_UPDATE_ENABLED=1 ;;
        --no-update) ;;
    esac
done

# ---------- Check-only mode ----------
# Read-only check; no agent run lock is needed and no files are changed.
if [ "$AUTO_UPDATE_CHECK_ONLY" = "1" ]; then
    if [ -f "${LIB_DIR}/auto_update.sh" ]; then
        source "${LIB_DIR}/auto_update.sh"
        auto_update_run
    else
        echo "[WARN] Auto-update library missing; cannot check for updates"
    fi
    exit 0
fi

# ---------- Acquire the run lock before updating ----------
# Holding the run lock across the update and the re-exec prevents another
# scheduled run from updating files underneath an active collector run.
[ -f "$LIB_DIR/common.sh" ] && source "$LIB_DIR/common.sh"
acquire_lock
trap 'release_lock' EXIT

# ---------- Automatic self-update ----------
# This runs before the rest of the libraries are sourced. If a new
# revision is pulled, the agent re-executes itself so every function
# and collector comes from the updated checkout. The re-exec keeps the
# same PID, so acquire_lock() recognizes the existing lock as its own.
if [ -f "${LIB_DIR}/auto_update.sh" ]; then
    source "${LIB_DIR}/auto_update.sh"
    auto_update_run
else
    echo "[WARN] Auto-update library missing; skipping update check"
fi

if [ "${AUTO_UPDATE_ABORT:-0}" = "1" ]; then
    echo "[ERROR] Auto-update could not restore a safe checkout; aborting run." >&2
    exit 1
fi

if [ "${AUTO_UPDATE_UPDATED:-0}" = "1" ] && \
   [ "${AUTO_UPDATE_REEXEC:-1}" != "0" ] && \
   [ "${AGENT_UPDATE_REEXEC:-0}" != "1" ]; then
    export AGENT_UPDATE_REEXEC=1
    echo "[INFO] Restarting agent with updated code..."
    if [ -x "${PROJECT_ROOT}/agent.sh" ]; then
        exec "${PROJECT_ROOT}/agent.sh" "$@"
    else
        exec bash "${PROJECT_ROOT}/agent.sh" "$@"
    fi
fi

# ---------- Source remaining libraries ----------
# common.sh was already sourced above for the run lock.
[ -f "$LIB_DIR/health.sh" ] && source "$LIB_DIR/health.sh"
[ -f "$LIB_DIR/pdf.sh" ] && source "$LIB_DIR/pdf.sh"
[ -f "$LIB_DIR/json.sh" ] && source "$LIB_DIR/json.sh"
[ -f "$LIB_DIR/json_v2.sh" ] && source "$LIB_DIR/json_v2.sh"
[ -f "$LIB_DIR/management_report.sh" ] && source "$LIB_DIR/management_report.sh"
[ -f "$LIB_DIR/transport.sh" ] && source "$LIB_DIR/transport.sh"
[ -f "$LIB_DIR/configurator.sh" ] && source "$LIB_DIR/configurator.sh"

if [ "$MODE" = "--list" ]; then
    list_collectors
    exit 0
fi

if [ "$MODE" = "--config" ]; then
    configurator_parse_args "$@"
    configurator_run
    exit 0
fi

# ---------- Initialize ----------
agent_init
AGENT_RUN_START_MS="$(date +%s%3N)"

if [ -n "$ARG_TECHNICIAN" ]; then
    DATA["general.technician"]="$ARG_TECHNICIAN"
else
    DATA["general.technician"]="Parsavan"
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
    DOMAIN_FALLBACK="$(resolve_mail_domain)"
    DATA["general.company"]="${DOMAIN_FALLBACK:-${DATA[agent.hostname]:-Unknown Host}}"
fi

# Keep one stable key for the domain that carries mail. Some collectors set it
# late; the fallback makes reports and JSON consistent even on partial runs.
if [ -z "${DATA[domain.primary.name]:-}" ]; then
    DOMAIN_FALLBACK="$(resolve_mail_domain)"
    [ -n "$DOMAIN_FALLBACK" ] && DATA["domain.primary.name"]="$DOMAIN_FALLBACK"
fi

echo "[INFO] Evaluating health..."
evaluate_health

echo "[INFO] Building JSON..."
build_json

echo "[INFO] Building JSON v2..."
if declare -F build_json_v2 >/dev/null; then
    build_json_v2 || echo "[WARN] health.v2.json could not be written" >&2
fi

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
