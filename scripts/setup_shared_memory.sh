#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# setup_shared_memory.sh — Set up shared memory system for 3 Clawdbot instances
#
# Creates a git-backed shared knowledge base at /opt/clawdbot-memory/ that all
# 3 bot instances can read/write via symlinks in their workspace directories.
# Memories auto-sync to a private GitHub repo every 5 minutes.
#
# Run on the Hetzner VM as root:
#   sudo bash setup_shared_memory.sh
#
# Prerequisites:
#   - deploy_clawdbot_vm.sh already run (instances at /opt/clawdbot-{1,2,3})
#   - Private GitHub repo created: jia-seed/clawdbot-memory
#   - git installed on the VM
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
MEMORY_DIR="/opt/clawdbot-memory"
CLAWDBOT_USER="clawdbot"
CLAWDBOT_GROUP="clawdbot"
GITHUB_REPO="jia-seed/clawdbot-memory"
INSTANCE_COUNT=3
DEPLOY_KEY_DIR="${MEMORY_DIR}/.deploy-key"
SYNC_DIR="${MEMORY_DIR}/.sync"
SERVICE_FILE="/etc/systemd/system/clawdbot@.service"

# ─── Preflight ────────────────────────────────────────────────────────────────
if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: Run as root (sudo)." >&2
  exit 1
fi

if ! command -v git &>/dev/null; then
  echo "ERROR: git is not installed. Run: apt install -y git" >&2
  exit 1
fi

for i in $(seq 1 $INSTANCE_COUNT); do
  if [[ ! -d "/opt/clawdbot-${i}" ]]; then
    echo "ERROR: /opt/clawdbot-${i} does not exist. Run deploy_clawdbot_vm.sh first." >&2
    exit 1
  fi
done

echo ""
echo "══════════════════════════════════════════════════════"
echo "  Clawdbot Shared Memory Setup"
echo "══════════════════════════════════════════════════════"
echo ""

# ─── [1/8] Create directory structure ─────────────────────────────────────────
echo "[1/8] Creating shared memory directory structure..."

mkdir -p "${MEMORY_DIR}/shared"
mkdir -p "${MEMORY_DIR}/bot-1-research"
mkdir -p "${MEMORY_DIR}/bot-2-ops"
mkdir -p "${MEMORY_DIR}/bot-3-strategy"
mkdir -p "${DEPLOY_KEY_DIR}"
mkdir -p "${SYNC_DIR}"

# ─── Create initial memory files ─────────────────────────────────────────────

# README for the memory repo
cat > "${MEMORY_DIR}/README.md" << 'HEREDOC'
# Clawdbot Shared Memory

Shared knowledge base for 3 Clawdbot Discord bot instances.
Auto-synced to GitHub every 5 minutes from the Hetzner VM.

## Structure

- `shared/` — Cross-bot knowledge (all bots read/write)
- `bot-1-research/` — Research bot (cornbread) notes
- `bot-2-ops/` — Ops bot (ricebread) notes
- `bot-3-strategy/` — Strategy bot (ubebread) notes

## How Bots Use This

Each bot sees this directory at `workspace/memory/` via symlink.

- To save a memory: write to `memory/shared/` or your bot's directory
- To read shared knowledge: read files in `memory/shared/`
- To read another bot's notes: read files in `memory/bot-N-role/`

## Warning

Do NOT store API keys, tokens, passwords, or credentials here.
This syncs to GitHub — anything written here is stored remotely.
HEREDOC

# Shared memory files
cat > "${MEMORY_DIR}/shared/project-context.md" << 'HEREDOC'
# Project Context

## Team

| Bot | Name | Instance | Role |
|-----|------|----------|------|
| cornbread | Clawdbot-Research | #1 | Market analysis, web search, data gathering |
| ricebread | Clawdbot-Ops | #2 | DevOps, server management, monitoring |
| ubebread | Clawdbot-Strategy | #3 | Planning, roadmaps, decision frameworks |

## Key Decisions

<!-- Append decisions here as they are made -->
HEREDOC

cat > "${MEMORY_DIR}/shared/team-knowledge.md" << 'HEREDOC'
# Team Knowledge

Shared facts, learnings, and context that all bots should know.

<!-- Append entries with timestamps -->
HEREDOC

cat > "${MEMORY_DIR}/shared/decisions.md" << 'HEREDOC'
# Decisions Log

Record of important decisions made across conversations.

<!-- Format: ## YYYY-MM-DD: Decision Title -->
HEREDOC

cat > "${MEMORY_DIR}/shared/links-and-resources.md" << 'HEREDOC'
# Links & Resources

Useful links, tools, and references collected by the team.

<!-- Format: - [Title](URL) — description -->
HEREDOC

# Per-bot memory files
cat > "${MEMORY_DIR}/bot-1-research/notes.md" << 'HEREDOC'
# Research Notes (cornbread)

## Quick Reference

## Working Memory

## Log
HEREDOC

cat > "${MEMORY_DIR}/bot-1-research/research-log.md" << 'HEREDOC'
# Research Log

<!-- Format: ## YYYY-MM-DD: Topic -->
HEREDOC

cat > "${MEMORY_DIR}/bot-1-research/sources.md" << 'HEREDOC'
# Sources & References

<!-- Format: - [Title](URL) — summary -->
HEREDOC

cat > "${MEMORY_DIR}/bot-2-ops/notes.md" << 'HEREDOC'
# Ops Notes (ricebread)

## Quick Reference

## Working Memory

## Log
HEREDOC

cat > "${MEMORY_DIR}/bot-2-ops/runbooks.md" << 'HEREDOC'
# Runbooks

Standard procedures and commands for common operations.
HEREDOC

cat > "${MEMORY_DIR}/bot-2-ops/incident-log.md" << 'HEREDOC'
# Incident Log

<!-- Format: ## YYYY-MM-DD HH:MM: Incident Title -->
HEREDOC

cat > "${MEMORY_DIR}/bot-3-strategy/notes.md" << 'HEREDOC'
# Strategy Notes (ubebread)

## Quick Reference

## Working Memory

## Log
HEREDOC

cat > "${MEMORY_DIR}/bot-3-strategy/roadmap.md" << 'HEREDOC'
# Roadmap

## Current Quarter

## Next Quarter

## Backlog
HEREDOC

cat > "${MEMORY_DIR}/bot-3-strategy/decisions-log.md" << 'HEREDOC'
# Strategy Decisions Log

<!-- Format: ## YYYY-MM-DD: Decision Title -->
HEREDOC

# .gitignore for the memory repo
cat > "${MEMORY_DIR}/.gitignore" << 'HEREDOC'
.deploy-key/
.sync/
HEREDOC

echo "  Created directory structure and initial files."

# ─── [2/8] Generate deploy key ───────────────────────────────────────────────
echo "[2/8] Generating deploy key for GitHub..."

if [[ -f "${DEPLOY_KEY_DIR}/id_ed25519" ]]; then
  echo "  Deploy key already exists, skipping generation."
else
  ssh-keygen -t ed25519 -C "clawdbot-memory-deploy" \
    -f "${DEPLOY_KEY_DIR}/id_ed25519" -N "" -q
  echo "  Generated new deploy key."
fi

# Create SSH config for this deploy key
cat > "${DEPLOY_KEY_DIR}/config" << HEREDOC
Host github-memory
  HostName github.com
  User git
  IdentityFile ${DEPLOY_KEY_DIR}/id_ed25519
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
HEREDOC

echo ""
echo "══════════════════════════════════════════════════════"
echo "  ACTION REQUIRED: Add this deploy key to GitHub"
echo "══════════════════════════════════════════════════════"
echo ""
echo "  1. Go to: https://github.com/${GITHUB_REPO}/settings/keys"
echo "  2. Click 'Add deploy key'"
echo "  3. Title: clawdbot-vm"
echo "  4. Check 'Allow write access'"
echo "  5. Paste this public key:"
echo ""
cat "${DEPLOY_KEY_DIR}/id_ed25519.pub"
echo ""
echo "══════════════════════════════════════════════════════"
echo ""
read -r -p "Press ENTER after adding the deploy key to GitHub..."

# ─── [3/8] Initialize git repo ───────────────────────────────────────────────
echo "[3/8] Initializing git repository..."

cd "$MEMORY_DIR"

if [[ -d ".git" ]]; then
  echo "  Git repo already initialized, skipping."
else
  git init -b main
  git config user.name "Clawdbot Memory"
  git config user.email "clawdbot@localhost"
fi

# Set remote
git remote remove origin 2>/dev/null || true
git remote add origin "git@github-memory:${GITHUB_REPO}.git"

# Configure SSH command for this repo
git config core.sshCommand "ssh -F ${DEPLOY_KEY_DIR}/config"

echo "  Git initialized with remote: ${GITHUB_REPO}"

# ─── [4/8] Initial commit & push ─────────────────────────────────────────────
echo "[4/8] Creating initial commit and pushing to GitHub..."

git add -A
git commit -m "Initialize shared memory for 3 Clawdbot instances

Directory structure:
- shared/ — cross-bot knowledge
- bot-1-research/ — cornbread's notes
- bot-2-ops/ — ricebread's notes
- bot-3-strategy/ — ubebread's notes" 2>/dev/null || echo "  Nothing new to commit."

export GIT_SSH_COMMAND="ssh -F ${DEPLOY_KEY_DIR}/config"

if git push -u origin main 2>&1; then
  echo "  Pushed to GitHub successfully."
else
  echo "  ERROR: Push failed. Check deploy key and repo settings." >&2
  echo "  You can retry manually: cd ${MEMORY_DIR} && GIT_SSH_COMMAND='ssh -F ${DEPLOY_KEY_DIR}/config' git push -u origin main"
  exit 1
fi

# ─── [5/8] Create workspace symlinks ─────────────────────────────────────────
echo "[5/8] Creating symlinks in each instance's workspace..."

for i in $(seq 1 $INSTANCE_COUNT); do
  WORKSPACE="/opt/clawdbot-${i}/workspace"
  LINK="${WORKSPACE}/memory"

  # Create workspace dir if it doesn't exist
  mkdir -p "$WORKSPACE"

  if [[ -L "$LINK" ]]; then
    echo "  Instance ${i}: symlink already exists, updating."
    rm "$LINK"
  elif [[ -d "$LINK" ]]; then
    echo "  Instance ${i}: WARNING — memory/ is a real directory, backing up to memory.bak/"
    mv "$LINK" "${LINK}.bak"
  fi

  ln -s "$MEMORY_DIR" "$LINK"
  echo "  Instance ${i}: ${LINK} -> ${MEMORY_DIR}"
done

# ─── [6/8] Update systemd service ────────────────────────────────────────────
echo "[6/8] Updating systemd ReadWritePaths..."

if [[ ! -f "$SERVICE_FILE" ]]; then
  echo "  WARNING: ${SERVICE_FILE} not found. You may need to manually add ReadWritePaths."
else
  if grep -q "clawdbot-memory" "$SERVICE_FILE"; then
    echo "  ReadWritePaths already includes clawdbot-memory, skipping."
  else
    # Add /opt/clawdbot-memory to ReadWritePaths
    sed -i "s|^ReadWritePaths=.*|& /opt/clawdbot-memory|" "$SERVICE_FILE"
    echo "  Added /opt/clawdbot-memory to ReadWritePaths."
    systemctl daemon-reload
    echo "  Reloaded systemd daemon."
  fi
fi

# ─── [7/8] Install sync script & cron job ────────────────────────────────────
echo "[7/8] Installing sync script and cron job..."

# Copy sync script into the sync directory
cp "$(dirname "$0")/sync-memory.sh" "${SYNC_DIR}/sync-memory.sh" 2>/dev/null || {
  # If sync-memory.sh isn't in the same directory, check /root/
  if [[ -f "/root/sync-memory.sh" ]]; then
    cp "/root/sync-memory.sh" "${SYNC_DIR}/sync-memory.sh"
  else
    echo "  ERROR: sync-memory.sh not found. Place it next to this script or in /root/."
    exit 1
  fi
}
chmod 700 "${SYNC_DIR}/sync-memory.sh"

# Create empty log and lock files
touch "${SYNC_DIR}/sync.log"
touch "${SYNC_DIR}/sync.lock"

# Install cron job for the clawdbot user
CRON_LINE="*/5 * * * * ${SYNC_DIR}/sync-memory.sh"
(crontab -u "$CLAWDBOT_USER" -l 2>/dev/null | grep -v "sync-memory" || true; echo "$CRON_LINE") \
  | crontab -u "$CLAWDBOT_USER" -

echo "  Installed cron job: every 5 minutes as ${CLAWDBOT_USER}"
echo "  Sync script: ${SYNC_DIR}/sync-memory.sh"

# ─── [8/8] Fix permissions & restart services ────────────────────────────────
echo "[8/8] Fixing permissions and restarting services..."

# Fix memory directory permissions
chown -R "${CLAWDBOT_USER}:${CLAWDBOT_GROUP}" "$MEMORY_DIR"
find "$MEMORY_DIR" -type d -exec chmod 700 {} \;
find "$MEMORY_DIR" -type f -exec chmod 600 {} \;
chmod 700 "${SYNC_DIR}/sync-memory.sh"

# Fix instance directory permissions (symlinks may have changed ownership)
for i in $(seq 1 $INSTANCE_COUNT); do
  chown -R "${CLAWDBOT_USER}:${CLAWDBOT_GROUP}" "/opt/clawdbot-${i}"
done

# Stagger restart all services
for i in $(seq 1 $INSTANCE_COUNT); do
  echo "  Restarting clawdbot@${i}..."
  systemctl restart "clawdbot@${i}"
  sleep 35
done

# Verify services
echo ""
echo "  Service status:"
for i in $(seq 1 $INSTANCE_COUNT); do
  STATUS=$(systemctl is-active "clawdbot@${i}" 2>/dev/null || echo "unknown")
  echo "    clawdbot@${i}: ${STATUS}"
done

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo "  SHARED MEMORY SETUP COMPLETE"
echo "══════════════════════════════════════════════════════"
echo ""
echo "  Memory directory:  ${MEMORY_DIR}"
echo "  GitHub repo:       https://github.com/${GITHUB_REPO}"
echo "  Sync interval:     every 5 minutes (cron)"
echo "  Sync log:          ${SYNC_DIR}/sync.log"
echo ""
echo "  Each bot sees memory at: workspace/memory/"
echo ""
echo "  Verify symlinks:"
echo "    ls -la /opt/clawdbot-1/workspace/memory"
echo "    ls -la /opt/clawdbot-2/workspace/memory"
echo "    ls -la /opt/clawdbot-3/workspace/memory"
echo ""
echo "  Test it:"
echo "    In Discord: @cornbread save a note to memory/bot-1-research/notes.md"
echo "    Wait 5 min, then check: https://github.com/${GITHUB_REPO}"
echo ""
