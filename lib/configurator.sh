#!/bin/bash
# lib/configurator.sh

CONFIGURATOR_FILE="${PROJECT_ROOT}/config/recommended.conf"
CONFIGURATOR_APPLY=0
CONFIGURATOR_DRY_RUN=0

configurator_parse_args() {
    for ARG in "$@"; do
        case "$ARG" in
            --apply)   CONFIGURATOR_APPLY=1 ;;
            --dry-run) CONFIGURATOR_DRY_RUN=1 ;;
        esac
    done
}

configurator_run() {
    if [ ! -f "$CONFIGURATOR_FILE" ]; then
        echo "[ERROR] Config file not found: $CONFIGURATOR_FILE" >&2
        return 1
    fi
    if [ ! -x "$IW_TOOL" ]; then
        echo "[ERROR] tool.sh not found or not executable: $IW_TOOL" >&2
        return 1
    fi

    local CHANGES_FILE="/tmp/configurator-changes.$$"
    : > "$CHANGES_FILE"

    local PENDING=0 SKIPPED=0 OK=0

    echo "=========================================="
    echo "  IceWarp Configurator"
    echo "=========================================="
    echo ""

    while IFS='|' read -r KEY DESIRED DESC; do
        [ -z "$KEY" ] && continue
        [[ "$KEY" =~ ^# ]] && continue

        # Check if key exists (allow leading spaces and case differences)
        local RAW
        RAW="$(timeout "${TOOL_TIMEOUT:-5}" "$IW_TOOL" display system "$KEY" 2>/dev/null)"

        if ! printf '%s\n' "$RAW" | grep -qiE "^[[:space:]]*${KEY}[[:space:]]*:"; then
            echo "[SKIP] $KEY ($DESC) - key not found"
            SKIPPED=$((SKIPPED+1))
            continue
        fi

        # Key exists, extract value (could be empty)
        local CURRENT
        CURRENT="$(printf '%s\n' "$RAW" | sed -E "s/^[[:space:]]*${KEY}[[:space:]]*:[[:space:]]*//I" | tr -d '[:space:]')"
        DESIRED="$(printf '%s' "$DESIRED" | tr -d '[:space:]')"

        if [ "$CURRENT" = "$DESIRED" ]; then
            echo "[OK]   $KEY ($DESC) = $DESIRED"
            OK=$((OK+1))
        else
            echo "[CHG]  $KEY ($DESC): '$CURRENT' -> $DESIRED"
            printf '%s|%s|%s\n' "$KEY" "$DESIRED" "$DESC" >> "$CHANGES_FILE"
            PENDING=$((PENDING+1))
        fi
    done < "$CONFIGURATOR_FILE"

    echo ""
    echo "=========================================="
    echo "Summary:"
    echo "  Already correct : $OK"
    echo "  Will change     : $PENDING"
    echo "  Skipped (no key): $SKIPPED"
    echo "=========================================="

    if [ "$PENDING" -eq 0 ]; then
        echo "Nothing to do."
        rm -f "$CHANGES_FILE"
        return 0
    fi

    if [ "$CONFIGURATOR_DRY_RUN" -eq 1 ]; then
        echo ""
        echo "DRY-RUN: no changes applied. Use --apply to apply."
        rm -f "$CHANGES_FILE"
        return 0
    fi

    if [ "$CONFIGURATOR_APPLY" -eq 0 ]; then
        echo ""
        echo "Run with --apply to apply these changes."
        rm -f "$CHANGES_FILE"
        return 0
    fi

    echo ""
    echo "Applying changes..."
    local FAIL=0
    while IFS='|' read -r KEY DESIRED DESC; do
        printf "  %-55s -> %-15s ... " "$KEY" "$DESIRED"
        if timeout "${TOOL_TIMEOUT:-5}" "$IW_TOOL" set system "$KEY" "$DESIRED" >/dev/null 2>&1; then
            echo "OK"
        else
            echo "FAIL"
            FAIL=$((FAIL+1))
        fi
    done < "$CHANGES_FILE"

    echo ""
    echo "=========================================="
    if [ "$FAIL" -eq 0 ]; then
        echo "All changes applied successfully."
    else
        echo "$FAIL change(s) failed."
    fi
    echo "=========================================="

    echo ""
    echo "Verification (re-reading all values):"
    while IFS='|' read -r KEY DESIRED DESC; do
        local RAW
        RAW="$(timeout "${TOOL_TIMEOUT:-5}" "$IW_TOOL" display system "$KEY" 2>/dev/null)"
        if printf '%s\n' "$RAW" | grep -qiE "^[[:space:]]*${KEY}[[:space:]]*:"; then
            local CURRENT
            CURRENT="$(printf '%s\n' "$RAW" | sed -E "s/^[[:space:]]*${KEY}[[:space:]]*:[[:space:]]*//I" | tr -d '[:space:]')"
            if [ "$CURRENT" = "$DESIRED" ]; then
                echo "  [OK]   $KEY = '$CURRENT'"
            else
                echo "  [FAIL] $KEY = '$CURRENT' (expected '$DESIRED')"
            fi
        else
            echo "  [FAIL] $KEY - key not found during verification"
        fi
    done < "$CHANGES_FILE"

    rm -f "$CHANGES_FILE"
    return 0
}
