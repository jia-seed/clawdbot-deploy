#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# sync-memory.sh — Git auto-sync for shared Clawdbot memory
#
# Runs via cron every 5 minutes as user 'clawdbot'.
# Commits any changes and pushes to the private GitHub repo.
# Pulls remote changes (manual GitHub edits) on each run.
#
# Installed by setup_shared_memory.sh — do not run manually.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
MEMORY_DIR="/opt/clawdbot-memory"
SYNC_DIR="${MEMORY_DIR}/.sync"
LOCK_FILE="${SYNC_DIR}/sync.lock"
LOG_FILE="${SYNC_DIR}/sync.log"
SSH_CONFIG="${MEMORY_DIR}/.deploy-key/config"
MAX_LOG_LINES=500

export GIT_SSH_COMMAND="ssh -F ${SSH_CONFIG}"

# ─── Logging ──────────────────────────────────────────────────────────────────
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ─── Truncate log if too long ─────────────────────────────────────────────────
if [[ -f "$LOG_FILE" ]] && [[ $(wc -l < "$LOG_FILE") -gt $MAX_LOG_LINES ]]; then
  tail -n 200 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi

# ─── Prevent concurrent runs ─────────────────────────────────────────────────
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "Sync already running, skipping."
  exit 0
fi

cd "$MEMORY_DIR"

# ─── Pull remote changes first ───────────────────────────────────────────────
# Pick up any manual edits made directly on GitHub
git pull --rebase origin main >> "$LOG_FILE" 2>&1 || {
  log "WARNING: Pull failed. Will try again next cycle."
}

# ─── Check for local changes ─────────────────────────────────────────────────
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  # No changes
  exit 0
fi

# ─── Stage all changes ───────────────────────────────────────────────────────
git add -A

# ─── Commit with timestamp + changed file summary ────────────────────────────
CHANGED=$(git diff --cached --name-only | head -20)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

git commit -m "$(cat <<EOF
Auto-sync: ${TIMESTAMP}

Changed files:
${CHANGED}
EOF
)" >> "$LOG_FILE" 2>&1 || {
  log "Nothing to commit."
  exit 0
}

# ─── Push with retry ─────────────────────────────────────────────────────────
for attempt in 1 2 3; do
  if git push origin main >> "$LOG_FILE" 2>&1; then
    log "Pushed successfully."
    exit 0
  else
    log "Push attempt ${attempt}/3 failed, retrying in 5s..."
    sleep 5
  fi
done

log "ERROR: All push attempts failed. Changes committed locally — will retry next cycle."
