#!/bin/bash

# ============================================================
# Automatic fast-forward updater
# ============================================================
# Runs before the agent sources its libraries. The updater only
# fast-forwards a checkout with no staged/code changes, validates the
# new shell files, and logs every attempt. Network/git failures never
# abort the agent; they are logged and the current revision is used.
# Unstaged per-server edits under config/*.conf are preserved.
# ============================================================

AUTO_UPDATE_ENABLED="${AUTO_UPDATE_ENABLED:-1}"
AUTO_UPDATE_REMOTE="${AUTO_UPDATE_REMOTE:-origin}"
AUTO_UPDATE_BRANCH="${AUTO_UPDATE_BRANCH:-main}"
AUTO_UPDATE_TIMEOUT="${AUTO_UPDATE_TIMEOUT:-60}"
AUTO_UPDATE_LOG="${AUTO_UPDATE_LOG:-${PROJECT_ROOT}/logs/auto_update.log}"
AUTO_UPDATE_LOG_MAX_BYTES="${AUTO_UPDATE_LOG_MAX_BYTES:-5242880}"
AUTO_UPDATE_EXPECTED_ORIGIN="${AUTO_UPDATE_EXPECTED_ORIGIN-kashiparsavan/icewarp-health-agent}"
AUTO_UPDATE_REEXEC="${AUTO_UPDATE_REEXEC:-1}"
AUTO_UPDATE_VALIDATE="${AUTO_UPDATE_VALIDATE:-1}"

[[ "$AUTO_UPDATE_TIMEOUT" =~ ^[0-9]+$ ]] || AUTO_UPDATE_TIMEOUT=60
[[ "$AUTO_UPDATE_LOG_MAX_BYTES" =~ ^[0-9]+$ ]] || AUTO_UPDATE_LOG_MAX_BYTES=5242880

AUTO_UPDATE_UPDATED=0
AUTO_UPDATE_ABORT=0
AUTO_UPDATE_STATUS=""
AUTO_UPDATE_OLD_SHA=""
AUTO_UPDATE_NEW_SHA=""

_au_short() {
    printf '%s' "${1:0:12}"
}

_au_lock_dir() {
    printf '%s/.agent.update.lock' "$PROJECT_ROOT"
}

_au_lock() {
    local LOCK
    local PID

    LOCK="$(_au_lock_dir)"

    if mkdir "$LOCK" 2>/dev/null; then
        printf '%s\n' "$$" > "${LOCK}/pid" 2>/dev/null || true
        return 0
    fi

    PID="$(cat "${LOCK}/pid" 2>/dev/null || true)"
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        return 1
    fi

    # Stale lock from an interrupted run.
    rm -rf "$LOCK" 2>/dev/null || return 1
    if mkdir "$LOCK" 2>/dev/null; then
        printf '%s\n' "$$" > "${LOCK}/pid" 2>/dev/null || true
        return 0
    fi

    return 1
}

_au_unlock() {
    rm -rf "$(_au_lock_dir)" 2>/dev/null || true
}

_au_rotate_log() {
    local LOG="$1"
    local SIZE

    [ -f "$LOG" ] || return 0
    SIZE="$(wc -c < "$LOG" 2>/dev/null | tr -d '[:space:]')"
    [[ "$SIZE" =~ ^[0-9]+$ ]] || return 0

    if [ "$SIZE" -gt "$AUTO_UPDATE_LOG_MAX_BYTES" ]; then
        mv -f "$LOG" "${LOG}.1" 2>/dev/null || true
    fi
}

_au_log() {
    local STATUS="$1"
    local OLD_SHA="${2:-}"
    local NEW_SHA="${3:-}"
    local DETAIL="${4:-}"
    local LOG="${AUTO_UPDATE_LOG:-${PROJECT_ROOT}/logs/auto_update.log}"
    local LINE

    AUTO_UPDATE_STATUS="$STATUS"
    AUTO_UPDATE_OLD_SHA="$OLD_SHA"
    AUTO_UPDATE_NEW_SHA="$NEW_SHA"

    DETAIL="${DETAIL//$'\n'/ }"
    DETAIL="${DETAIL//$'\r'/ }"
    DETAIL="${DETAIL//|//}"
    DETAIL="$(printf '%s' "$DETAIL" | sed -E 's#(https?://)[^/@[:space:]]+@#\1***@#g')"
    DETAIL="${DETAIL:0:500}"
    OLD_SHA="${OLD_SHA//|//}"
    NEW_SHA="${NEW_SHA//|//}"

    mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
    _au_rotate_log "$LOG"

    LINE="$(date -u '+%Y-%m-%dT%H:%M:%SZ')|${STATUS}|old=${OLD_SHA:-none}|new=${NEW_SHA:-none}|branch=${AUTO_UPDATE_BRANCH}|${DETAIL}"

    if ! printf '%s\n' "$LINE" >> "$LOG" 2>/dev/null; then
        echo "[WARN] Auto-update: could not write log: $LOG" >&2
    fi
}

_au_git() {
    GIT_TERMINAL_PROMPT=0 LC_ALL=C timeout "$AUTO_UPDATE_TIMEOUT" \
        git -C "$PROJECT_ROOT" "$@"
}

_au_dirty() {
    local DIFF
    local FILE

    # Staged changes are never safe to carry through a fast-forward.
    if ! _au_git diff --cached --quiet --ignore-submodules -- 2>/dev/null; then
        return 0
    fi

    # Unstaged per-server settings in config/*.conf are allowed. Git will
    # still abort the merge if an incoming commit touches the same file.
    DIFF="$(_au_git diff --name-only --ignore-submodules -- 2>/dev/null)" || return 0
    [ -z "$DIFF" ] && return 1

    while IFS= read -r FILE; do
        [ -z "$FILE" ] && continue
        case "$FILE" in
            config/*.conf) ;;
            *) return 0 ;;
        esac
    done <<< "$DIFF"

    return 1
}

_au_normalize_remote() {
    local URL="$1"

    URL="${URL%.git}"
    URL="${URL%/}"

    case "$URL" in
        https://github.com/*) URL="${URL#https://github.com/}" ;;
        http://github.com/*) URL="${URL#http://github.com/}" ;;
        git@github.com:*) URL="${URL#git@github.com:}" ;;
        ssh://git@github.com/*) URL="${URL#ssh://git@github.com/}" ;;
        *) return 1 ;;
    esac

    printf '%s' "$URL" | tr '[:upper:]' '[:lower:]'
}

_au_has_config_changes() {
    ! _au_git diff --quiet --ignore-submodules -- config/*.conf 2>/dev/null
}

_au_origin_allowed() {
    local REMOTE_URL
    local NORMALIZED_URL
    local NORMALIZED_EXPECTED

    [ -n "$AUTO_UPDATE_EXPECTED_ORIGIN" ] || return 0

    REMOTE_URL="$(_au_git remote get-url "$AUTO_UPDATE_REMOTE" 2>/dev/null)" || return 1
    NORMALIZED_URL="$(_au_normalize_remote "$REMOTE_URL")" || return 1

    NORMALIZED_EXPECTED="$(printf '%s' "$AUTO_UPDATE_EXPECTED_ORIGIN" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -e 's#^https://github.com/##' \
              -e 's#^http://github.com/##' \
              -e 's#^git@github.com:##' \
              -e 's#^ssh://git@github.com/##' \
              -e 's#\.git$##' \
              -e 's#/$##')"

    [ "$NORMALIZED_URL" = "$NORMALIZED_EXPECTED" ]
}

_au_validate_checkout() {
    local FILE

    [ "$AUTO_UPDATE_VALIDATE" = "1" ] || return 0

    if ! bash -n "${PROJECT_ROOT}/agent.sh" >/dev/null 2>&1; then
        return 1
    fi

    while IFS= read -r FILE; do
        if ! bash -n "$FILE" >/dev/null 2>&1; then
            return 1
        fi
    done < <(find "$PROJECT_ROOT" -type f -name '*.sh' \
        -not -path '*/.git/*' -not -path '*/logs/*' 2>/dev/null)

    return 0
}

_au_update_locked() {
    local OLD_SHA
    local REMOTE_SHA
    local LOCAL_BRANCH
    local FETCH_OUT
    local MERGE_OUT
    local NEW_SHA
    local SUBJECT
    local COUNT
    local CONFIG_PATCH=""
    local RESTORE_MSG=""

    if ! _au_git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        _au_log "not_git" "" "" "PROJECT_ROOT is not a git work tree"
        echo "[INFO] Auto-update: not a git checkout; skipping"
        return 0
    fi

    OLD_SHA="$(_au_git rev-parse HEAD 2>/dev/null)" || {
        _au_log "error" "" "" "Cannot read local HEAD"
        echo "[WARN] Auto-update: cannot read local git HEAD; continuing"
        return 0
    }

    if ! _au_origin_allowed; then
        _au_log "origin_mismatch" "$OLD_SHA" "" \
            "Origin does not match AUTO_UPDATE_EXPECTED_ORIGIN=${AUTO_UPDATE_EXPECTED_ORIGIN}"
        echo "[WARN] Auto-update: git origin is not the expected repository; skipping"
        return 0
    fi

    LOCAL_BRANCH="$(_au_git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [ "$LOCAL_BRANCH" != "$AUTO_UPDATE_BRANCH" ]; then
        _au_log "wrong_branch" "$OLD_SHA" "" \
            "Checked-out branch is '${LOCAL_BRANCH}', not '${AUTO_UPDATE_BRANCH}'"
        echo "[INFO] Auto-update: checked-out branch is not ${AUTO_UPDATE_BRANCH}; skipping"
        return 0
    fi

    if _au_dirty; then
        _au_log "dirty_tree" "$OLD_SHA" "" "Working tree has code or staged changes; refusing to overwrite"
        echo "[WARN] Auto-update: working tree has code or staged changes; skipping"
        return 0
    fi

    if ! FETCH_OUT="$(_au_git fetch --quiet --prune "$AUTO_UPDATE_REMOTE" "$AUTO_UPDATE_BRANCH" 2>&1)"; then
        _au_log "fetch_failed" "$OLD_SHA" "" "$FETCH_OUT"
        echo "[WARN] Auto-update: git fetch failed; continuing with current code"
        return 0
    fi

    if ! REMOTE_SHA="$(_au_git rev-parse "${AUTO_UPDATE_REMOTE}/${AUTO_UPDATE_BRANCH}" 2>/dev/null)"; then
        _au_log "error" "$OLD_SHA" "" "Cannot resolve ${AUTO_UPDATE_REMOTE}/${AUTO_UPDATE_BRANCH}"
        echo "[WARN] Auto-update: remote branch is unavailable; continuing with current code"
        return 0
    fi

    if [ "$OLD_SHA" = "$REMOTE_SHA" ]; then
        if [ "${AUTO_UPDATE_CHECK_ONLY:-0}" = "1" ]; then
            _au_log "check_up_to_date" "$OLD_SHA" "$REMOTE_SHA" "No update available"
            echo "[INFO] Auto-update: up to date ($(_au_short "$OLD_SHA"))"
        else
            _au_log "up_to_date" "$OLD_SHA" "$REMOTE_SHA" "No update available"
            echo "[INFO] Auto-update: up to date ($(_au_short "$OLD_SHA"))"
        fi
        return 0
    fi

    if _au_git merge-base --is-ancestor "$OLD_SHA" "$REMOTE_SHA" 2>/dev/null; then
        COUNT="$(_au_git rev-list --count "${OLD_SHA}..${REMOTE_SHA}" 2>/dev/null || echo "?")"

        if [ "${AUTO_UPDATE_CHECK_ONLY:-0}" = "1" ]; then
            _au_log "check_available" "$OLD_SHA" "$REMOTE_SHA" \
                "Update available (${COUNT} commit(s))"
            echo "[INFO] Auto-update: update available $(_au_short "$OLD_SHA") -> $(_au_short "$REMOTE_SHA") (${COUNT} commit(s))"
            return 0
        fi

        # Preserve allowed per-server config edits before a merge so they can
        # be restored if the new revision fails validation.
        if _au_has_config_changes; then
            CONFIG_PATCH="$(mktemp "${TMPDIR:-/tmp}/icewarp-agent-config.XXXXXX" 2>/dev/null)" || {
                _au_log "error" "$OLD_SHA" "$REMOTE_SHA" \
                    "Cannot create temporary backup for local config changes; skipping update"
                echo "[WARN] Auto-update: cannot back up local config changes; skipping"
                return 0
            }
            if ! _au_git diff -- config/*.conf > "$CONFIG_PATCH" 2>/dev/null; then
                rm -f "$CONFIG_PATCH"
                _au_log "error" "$OLD_SHA" "$REMOTE_SHA" \
                    "Cannot capture local config changes; skipping update"
                echo "[WARN] Auto-update: cannot capture local config changes; skipping"
                return 0
            fi
        fi

        if ! MERGE_OUT="$(_au_git merge --ff-only "$REMOTE_SHA" 2>&1)"; then
            rm -f "$CONFIG_PATCH"
            _au_log "merge_failed" "$OLD_SHA" "$REMOTE_SHA" "$MERGE_OUT"
            echo "[WARN] Auto-update: fast-forward failed; continuing with current code"
            return 0
        fi

        NEW_SHA="$(_au_git rev-parse HEAD 2>/dev/null || true)"
        SUBJECT="$(_au_git log -1 --pretty=%s 2>/dev/null || true)"

        if ! _au_validate_checkout; then
            if ! _au_git reset --hard "$OLD_SHA" >/dev/null 2>&1; then
                AUTO_UPDATE_ABORT=1
                rm -f "$CONFIG_PATCH"
                _au_log "error" "$OLD_SHA" "$NEW_SHA" \
                    "Validation failed and rollback failed; aborting run"
                echo "[ERROR] Auto-update: validation failed and rollback failed; aborting"
                return 0
            fi

            if [ -n "$CONFIG_PATCH" ] && [ -s "$CONFIG_PATCH" ]; then
                if _au_git apply "$CONFIG_PATCH" >/dev/null 2>&1; then
                    RESTORE_MSG="Local config changes restored."
                else
                    cp "$CONFIG_PATCH" "${AUTO_UPDATE_LOG}.config.patch" 2>/dev/null || true
                    RESTORE_MSG="Local config changes could not be restored; backup=${AUTO_UPDATE_LOG}.config.patch"
                fi
            fi

            rm -f "$CONFIG_PATCH"
            _au_log "reverted" "$OLD_SHA" "$NEW_SHA" \
                "Post-update shell syntax validation failed; reverted to ${OLD_SHA}. ${RESTORE_MSG}"
            echo "[ERROR] Auto-update: new revision failed syntax validation; reverted"
            return 0
        fi

        rm -f "$CONFIG_PATCH"
        AUTO_UPDATE_UPDATED=1
        _au_log "updated" "$OLD_SHA" "$NEW_SHA" "Fast-forwarded: ${SUBJECT}"
        echo "[INFO] Auto-update: updated $(_au_short "$OLD_SHA") -> $(_au_short "$NEW_SHA"): ${SUBJECT}"
        return 0
    fi

    if _au_git merge-base --is-ancestor "$REMOTE_SHA" "$OLD_SHA" 2>/dev/null; then
        _au_log "ahead" "$OLD_SHA" "$REMOTE_SHA" "Local branch is ahead of the remote"
        echo "[INFO] Auto-update: local branch is ahead; skipping"
        return 0
    fi

    _au_log "diverged" "$OLD_SHA" "$REMOTE_SHA" "Local and remote histories diverged"
    echo "[WARN] Auto-update: local and remote histories diverged; skipping"
    return 0
}

auto_update_run() {
    if [ "${AGENT_UPDATE_REEXEC:-0}" = "1" ]; then
        _au_log "reexec_complete" "$(_au_git rev-parse HEAD 2>/dev/null || true)" \
            "$(_au_git rev-parse HEAD 2>/dev/null || true)" \
            "Re-executed after update; second update check skipped"
        echo "[INFO] Auto-update: re-exec complete"
        return 0
    fi

    if [ "${AUTO_UPDATE_DISABLED:-0}" = "1" ]; then
        _au_log "disabled" "" "" "Disabled by --no-auto-update"
        echo "[INFO] Auto-update: disabled by --no-auto-update"
        return 0
    fi

    if [ "$AUTO_UPDATE_ENABLED" != "1" ] && [ "${AUTO_UPDATE_CHECK_ONLY:-0}" != "1" ]; then
        _au_log "disabled" "" "" "Disabled by AUTO_UPDATE_ENABLED=${AUTO_UPDATE_ENABLED}"
        echo "[INFO] Auto-update: disabled"
        return 0
    fi

    if ! command -v git >/dev/null 2>&1; then
        _au_log "git_missing" "" "" "git is not installed"
        echo "[WARN] Auto-update: git is not installed; skipping"
        return 0
    fi

    if ! _au_lock; then
        _au_log "locked" "" "" "Another update check is already running"
        echo "[INFO] Auto-update: another update check is running; skipping"
        return 0
    fi

    _au_update_locked
    _au_unlock
    return 0
}
