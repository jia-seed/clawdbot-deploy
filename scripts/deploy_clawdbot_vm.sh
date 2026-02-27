#!/usr/bin/env bash
# deploy_clawdbot_vm.sh — Deploy 3 Clawdbot (OpenClaw) instances on Ubuntu 24.04
# Run as root: curl -fsSL <URL> | bash
# Idempotent: safe to re-run without breaking existing installs.
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
CLAWDBOT_USER="clawdbot"
CLAWDBOT_GROUP="clawdbot"
INSTANCE_COUNT=3
BASE_PORT=18789
BASE_DIR="/opt"
NODE_MAJOR=20
MEM_LIMIT="1G"

# ─── Preflight ────────────────────────────────────────────────────────────────
if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: Run this script as root (or with sudo)." >&2
  exit 1
fi

source /etc/os-release 2>/dev/null || true
if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "WARNING: This script targets Ubuntu 24.04. Detected: ${PRETTY_NAME:-unknown}"
  echo "Proceeding anyway..."
fi

echo "============================================"
echo "  Clawdbot VM Deploy — ${INSTANCE_COUNT} Instances"
echo "============================================"
echo ""

# ─── 1. System Update ────────────────────────────────────────────────────────
echo "[1/8] Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

# ─── 2. Install Node.js 20.x LTS ─────────────────────────────────────────────
echo "[2/8] Installing Node.js ${NODE_MAJOR}.x..."
if ! command -v node &>/dev/null || [[ "$(node -v | cut -d. -f1 | tr -d v)" -ne "$NODE_MAJOR" ]]; then
  apt-get install -y -qq ca-certificates curl gnupg
  mkdir -p /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/nodesource.gpg ]]; then
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  fi
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list
  apt-get update -qq
  apt-get install -y -qq nodejs
else
  echo "  Node.js $(node -v) already installed, skipping."
fi
echo "  Node: $(node -v) | npm: $(npm -v)"

# ─── 3. Install essential tools ──────────────────────────────────────────────
echo "[3/8] Installing utilities (ufw, jq)..."
apt-get install -y -qq ufw jq

# ─── 4. Create clawdbot system user ──────────────────────────────────────────
echo "[4/8] Creating system user '${CLAWDBOT_USER}'..."
if ! id "$CLAWDBOT_USER" &>/dev/null; then
  groupadd --system "$CLAWDBOT_GROUP"
  useradd --system \
    --gid "$CLAWDBOT_GROUP" \
    --shell /usr/sbin/nologin \
    --home-dir "/home/${CLAWDBOT_USER}" \
    --create-home \
    "$CLAWDBOT_USER"
  echo "  Created user ${CLAWDBOT_USER}"
else
  echo "  User ${CLAWDBOT_USER} already exists, skipping."
fi

# Allow clawdbot to run systemctl for its own services (for the config helper)
SUDOERS_FILE="/etc/sudoers.d/clawdbot"
if [[ ! -f "$SUDOERS_FILE" ]]; then
  cat > "$SUDOERS_FILE" <<'SUDOERS'
clawdbot ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart clawdbot@*, \
                              /usr/bin/systemctl stop clawdbot@*, \
                              /usr/bin/systemctl start clawdbot@*, \
                              /usr/bin/systemctl status clawdbot@*
SUDOERS
  chmod 440 "$SUDOERS_FILE"
  visudo -cf "$SUDOERS_FILE"  # validate syntax
fi

# ─── 5. Install clawdbot globally ────────────────────────────────────────────
echo "[5/8] Installing clawdbot globally..."
npm install -g clawdbot@latest 2>/dev/null || npm install -g clawdbot@latest
echo "  clawdbot installed: $(clawdbot --version 2>/dev/null || echo 'version check not supported')"

# ─── 6. Create instance directories + .env files ─────────────────────────────
echo "[6/8] Setting up ${INSTANCE_COUNT} instance directories..."
for i in $(seq 1 "$INSTANCE_COUNT"); do
  INST_DIR="${BASE_DIR}/clawdbot-${i}"
  PORT=$((BASE_PORT + i - 1))

  mkdir -p "$INST_DIR"

  # Generate .env only if it doesn't already exist (preserve user edits)
  if [[ ! -f "${INST_DIR}/.env" ]]; then
    cat > "${INST_DIR}/.env" <<ENV
# ── Clawdbot Instance ${i} ──────────────────────────
# Port: ${PORT} | Dir: ${INST_DIR}

# REQUIRED: Your Anthropic API key
ANTHROPIC_API_KEY=sk-ant-REPLACE_ME_INSTANCE_${i}

# Instance binding
CLAWDBOT_PORT=${PORT}
CLAWDBOT_HOST=127.0.0.1

# Optional: channel tokens (set via multi_clawdbot_config.sh or manually)
# DISCORD_TOKEN=
# TELEGRAM_BOT_TOKEN=
# WHATSAPP_SESSION_PATH=${INST_DIR}/whatsapp-session

# Optional: custom model
# CLAWDBOT_MODEL=claude-sonnet-4-5-20250929
ENV
    echo "  Created ${INST_DIR}/.env (placeholder)"
  else
    echo "  ${INST_DIR}/.env exists, preserving."
  fi

  # Lock down permissions
  chown -R "${CLAWDBOT_USER}:${CLAWDBOT_GROUP}" "$INST_DIR"
  chmod 700 "$INST_DIR"
  chmod 600 "${INST_DIR}/.env"
done

# ─── 7. Create systemd template unit ─────────────────────────────────────────
echo "[7/8] Creating systemd service template..."
cat > /etc/systemd/system/clawdbot@.service <<UNIT
[Unit]
Description=Clawdbot Instance %i
Documentation=https://github.com/openclaw/clawdbot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${CLAWDBOT_USER}
Group=${CLAWDBOT_GROUP}
WorkingDirectory=${BASE_DIR}/clawdbot-%i
EnvironmentFile=${BASE_DIR}/clawdbot-%i/.env

ExecStart=/usr/bin/clawdbot start --port \${CLAWDBOT_PORT} --host \${CLAWDBOT_HOST}
ExecReload=/bin/kill -HUP \$MAINPID

# ── Restart policy ──
Restart=always
RestartSec=5
StartLimitIntervalSec=60
StartLimitBurst=5

# ── Resource limits ──
MemoryMax=${MEM_LIMIT}
MemoryHigh=768M
CPUQuota=80%

# ── Security hardening ──
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=${BASE_DIR}/clawdbot-%i
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
RestrictNamespaces=true

# ── Logging ──
StandardOutput=journal
StandardError=journal
SyslogIdentifier=clawdbot-%i

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload

# Enable and start all instances
for i in $(seq 1 "$INSTANCE_COUNT"); do
  systemctl enable "clawdbot@${i}.service"
  # Only start if API key has been set (don't start with placeholder)
  ENV_FILE="${BASE_DIR}/clawdbot-${i}/.env"
  if grep -q "REPLACE_ME" "$ENV_FILE" 2>/dev/null; then
    echo "  clawdbot@${i}: enabled (not started — set API key first)"
  else
    systemctl restart "clawdbot@${i}.service"
    echo "  clawdbot@${i}: enabled + started"
  fi
done

# ─── 8. Firewall ─────────────────────────────────────────────────────────────
echo "[8/8] Configuring firewall (ufw)..."
ufw --force reset >/dev/null 2>&1
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw --force enable
echo "  UFW active: SSH only. Clawdbot ports are localhost-only (no rules needed)."

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  DEPLOYMENT COMPLETE"
echo "============================================"
echo ""
echo "Instance layout:"
for i in $(seq 1 "$INSTANCE_COUNT"); do
  PORT=$((BASE_PORT + i - 1))
  echo "  #${i}  ${BASE_DIR}/clawdbot-${i}  →  127.0.0.1:${PORT}"
done
echo ""
echo "NEXT STEPS:"
echo ""
echo "  1. Set API keys in each instance .env:"
echo "     sudo nano /opt/clawdbot-1/.env"
echo "     sudo nano /opt/clawdbot-2/.env"
echo "     sudo nano /opt/clawdbot-3/.env"
echo ""
echo "  2. Or use the config helper:"
echo "     sudo ./multi_clawdbot_config.sh 1"
echo ""
echo "  3. Start services after configuring:"
echo "     sudo systemctl start clawdbot@1"
echo "     sudo systemctl start clawdbot@2"
echo "     sudo systemctl start clawdbot@3"
echo ""
echo "  4. Check status:"
echo "     systemctl status clawdbot@{1,2,3}"
echo "     journalctl -u clawdbot@1 -f"
echo ""
echo "ACCESS PATTERNS (from your local machine):"
echo ""
echo "  SSH tunnel (one instance):"
echo "     ssh -L 8081:127.0.0.1:18789 user@YOUR_VM_IP"
echo "     ssh -L 8082:127.0.0.1:18790 user@YOUR_VM_IP"
echo "     ssh -L 8083:127.0.0.1:18791 user@YOUR_VM_IP"
echo ""
echo "  SSH tunnel (all at once):"
echo "     ssh -L 8081:127.0.0.1:18789 -L 8082:127.0.0.1:18790 -L 8083:127.0.0.1:18791 user@YOUR_VM_IP"
echo ""
echo "  Then open: http://localhost:8081 / 8082 / 8083"
echo ""
echo "  Tailscale (if installed):"
echo "     Access directly via Tailscale IP, but still localhost-bound."
echo "     To expose on Tailscale interface, edit .env CLAWDBOT_HOST=100.x.x.x"
echo ""
echo "============================================"
