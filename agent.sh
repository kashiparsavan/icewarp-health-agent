#!/bin/bash
# ============================================================
# IceWarp Health Agent - Entry Point
# ============================================================

# ---------- HELP CHECK (BEFORE ANYTHING ELSE) ----------
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "IceWarp Health Agent v$(cat /opt/icewarp/monitoring/VERSION 2>/dev/null || echo 'unknown')"
    echo ""
    echo "Usage: agent.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h                  Show this help message and exit"
    echo "  --report                    Generate a full health report (PDF + TXT)"
    echo "  --technician=\"NAME\"         Set technician name for the report"
    echo "  --no-update                 Disable automatic self-update"
    echo ""
    echo "Examples:"
    echo "  agent.sh --report --technician=\"Kashi\""
    echo "  agent.sh --help"
    exit 0
fi

# ---------- Self-Updater (Git-based) ----------
INSTALL_DIR="/opt/icewarp/monitoring"
VERSION_FILE="$INSTALL_DIR/VERSION"
CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "0.0.0")

check_and_update_via_git() {
    # Skip if disabled via argument
    if [[ "$*" == *"--no-update"* ]]; then
        echo "[SKIP] Self-update disabled by --no-update"
        return 0
    fi

    echo "[CHECK] Checking for updates via Git (origin/main)"
    
    cd "$INSTALL_DIR" || return 1

    # Fetch latest changes from remote
    git fetch origin main 2>/dev/null || {
        echo "[WARN] Git fetch failed. Skipping update."
        return 1
    }

    # Compare local and remote commits
    LOCAL_COMMIT=$(git rev-parse HEAD 2>/dev/null)
    REMOTE_COMMIT=$(git rev-parse origin/main 2>/dev/null)
    
    if [ -z "$LOCAL_COMMIT" ] || [ -z "$REMOTE_COMMIT" ]; then
        echo "[WARN] Could not determine commits. Skipping update."
        return 1
    fi

    if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
        echo "[OK] Agent is up-to-date (commit $LOCAL_COMMIT)"
        return 0
    fi

    echo "[UPDATE] New version available: $REMOTE_COMMIT (local: $LOCAL_COMMIT)"
    
    # Backup current installation
    BACKUP_DIR="/tmp/icewarp-agent-backup-$(date +%Y%m%d%H%M%S)"
    echo "[BACKUP] Creating backup at $BACKUP_DIR"
    cp -r "$INSTALL_DIR" "$BACKUP_DIR" 2>/dev/null

    # Pull latest changes
    echo "[PULL] Fetching latest from origin/main"
    git pull origin main --force || {
        echo "[ERROR] Git pull failed. Restoring backup..."
        rm -rf "$INSTALL_DIR"/*
        cp -r "$BACKUP_DIR"/* "$INSTALL_DIR/"
        return 1
    }

    # Set execute permissions
    find "$INSTALL_DIR" -type f -name "*.sh" -exec chmod +x {} \;
    chmod +x "$INSTALL_DIR/agent.sh"

    # Update VERSION file if it exists
    if [ -f "$INSTALL_DIR/VERSION" ]; then
        NEW_VERSION=$(cat "$INSTALL_DIR/VERSION")
        echo "[SUCCESS] Updated to version $NEW_VERSION"
    else
        echo "[SUCCESS] Updated to latest commit $REMOTE_COMMIT"
    fi

    # Re-execute the new agent with the same arguments
    echo "[RESTART] Launching new agent..."
    exec "$INSTALL_DIR/agent.sh" "$@"
}

# Run the updater (if not --help which we already checked)
check_and_update_via_git "$@"

# ============================================================
# ---------- ORIGINAL AGENT LOGIC (UNCHANGED) ----------
# ============================================================
# All existing code below this line stays exactly as it was.
# ============================================================

# (The rest of your original agent.sh code goes here)
# Including: report generation, PDF creation, etc.
