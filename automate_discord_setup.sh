#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# automate_discord_setup.sh — Connect 3 Clawdbot instances to Discord
#
# QUICK START (30 seconds):
#   sudo ./automate_discord_setup.sh \
#     "BOT_TOKEN_1" "BOT_TOKEN_2" "BOT_TOKEN_3" \
#     "SERVER_ID" "CHANNEL_1_ID" "CHANNEL_2_ID" "CHANNEL_3_ID"
#
# Run on the Hetzner VM as root. Idempotent — safe to re-run.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
BASE_DIR="/opt"
CLAWDBOT_USER="clawdbot"
CLAWDBOT_GROUP="clawdbot"
INSTANCE_COUNT=3
BASE_PORT=18789
LOG_FILE="/var/log/clawdbot-discord-setup.log"

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage:
  sudo ./automate_discord_setup.sh <token1> <token2> <token3> <server_id> <channel1> <channel2> <channel3>

Arguments:
  token1      Discord bot token for instance 1 (Research)
  token2      Discord bot token for instance 2 (Ops)
  token3      Discord bot token for instance 3 (Strategy)
  server_id   Discord server (guild) ID — same for all 3
  channel1    Channel ID for instance 1 (#research)
  channel2    Channel ID for instance 2 (#ops)
  channel3    Channel ID for instance 3 (#strategy)

Example:
  sudo ./automate_discord_setup.sh \
    "MTIz.abc.xyz" \
    "OTg3.def.uvw" \
    "NTY3.ghi.rst" \
    "1234567890123456789" \
    "1111111111111111111" \
    "2222222222222222222" \
    "3333333333333333333"

How to get these values:
  Tokens:     discord.com/developers → Application → Bot → Reset Token
  Server ID:  Right-click server name in Discord (Developer Mode on) → Copy Server ID
  Channel ID: Right-click channel name → Copy Channel ID
EOF
  exit 1
}

# ─── Preflight ────────────────────────────────────────────────────────────────
if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: Run as root (sudo)." >&2
  exit 1
fi

if [[ $# -ne 7 ]]; then
  echo "ERROR: Expected 7 arguments, got $#." >&2
  echo ""
  usage
fi

TOKEN_1="$1"
TOKEN_2="$2"
TOKEN_3="$3"
SERVER_ID="$4"
CHANNEL_1="$5"
CHANNEL_2="$6"
CHANNEL_3="$7"

# Map arrays for loop processing
TOKENS=("$TOKEN_1" "$TOKEN_2" "$TOKEN_3")
CHANNELS=("$CHANNEL_1" "$CHANNEL_2" "$CHANNEL_3")
NAMES=("Research" "Ops" "Strategy")

# ─── Logging ──────────────────────────────────────────────────────────────────
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "$msg"
  echo "$msg" >> "$LOG_FILE"
}

# ─── Validation ───────────────────────────────────────────────────────────────
log "═══════════════════════════════════════════════════"
log "  Clawdbot Discord Setup — ${INSTANCE_COUNT} Instances"
log "═══════════════════════════════════════════════════"

# Validate tokens look like Discord bot tokens (base64-ish with dots)
for i in 0 1 2; do
  TOKEN="${TOKENS[$i]}"
  if [[ ${#TOKEN} -lt 50 ]]; then
    log "WARNING: Token for instance $((i+1)) (${NAMES[$i]}) seems short (${#TOKEN} chars)."
    log "  Discord bot tokens are typically 70+ characters."
    log "  Proceeding anyway — double-check if you get auth errors."
  fi
done

# Validate server ID is numeric
if ! [[ "$SERVER_ID" =~ ^[0-9]+$ ]]; then
  echo "ERROR: Server ID must be numeric. Got: $SERVER_ID" >&2
  exit 1
fi

# Validate channel IDs are numeric
for i in 0 1 2; do
  if ! [[ "${CHANNELS[$i]}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Channel ID for instance $((i+1)) must be numeric. Got: ${CHANNELS[$i]}" >&2
    exit 1
  fi
done

log "Validated all inputs."

# ─── Configure Each Instance ─────────────────────────────────────────────────
for i in 0 1 2; do
  INST=$((i + 1))
  INST_DIR="${BASE_DIR}/clawdbot-${INST}"
  ENV_FILE="${INST_DIR}/.env"
  TOKEN="${TOKENS[$i]}"
  CHANNEL="${CHANNELS[$i]}"
  NAME="${NAMES[$i]}"
  PORT=$((BASE_PORT + i))

  log ""
  log "── Instance ${INST}: ${NAME} ──"
  log "  Dir:     ${INST_DIR}"
  log "  Port:    ${PORT}"
  log "  Channel: ${CHANNEL}"

  # Verify instance directory exists
  if [[ ! -d "$INST_DIR" ]]; then
    log "ERROR: ${INST_DIR} does not exist. Run deploy_clawdbot_vm.sh first."
    exit 1
  fi

  # Verify .env exists
  if [[ ! -f "$ENV_FILE" ]]; then
    log "ERROR: ${ENV_FILE} does not exist."
    exit 1
  fi

  # ── Update .env with Discord config ──
  # Function to set a key=value in the .env, replacing if exists, appending if not
  set_env() {
    local key="$1" value="$2" file="$3"
    # Remove any existing line (commented or not)
    sed -i "/^#*\s*${key}=/d" "$file"
    # Append the new value
    echo "${key}=${value}" >> "$file"
  }

  log "  Setting DISCORD_TOKEN..."
  set_env "DISCORD_TOKEN" "$TOKEN" "$ENV_FILE"

  log "  Setting DISCORD_SERVER_ID..."
  set_env "DISCORD_SERVER_ID" "$SERVER_ID" "$ENV_FILE"

  log "  Setting DISCORD_CHANNEL_ID..."
  set_env "DISCORD_CHANNEL_ID" "$CHANNEL" "$ENV_FILE"

  log "  Setting DISCORD_ALLOWED_CHANNELS..."
  set_env "DISCORD_ALLOWED_CHANNELS" "$CHANNEL" "$ENV_FILE"

  # ── Lock down permissions ──
  chown "${CLAWDBOT_USER}:${CLAWDBOT_GROUP}" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  log "  Permissions set (600, ${CLAWDBOT_USER}:${CLAWDBOT_GROUP})"

  # ── Restart the service ──
  log "  Restarting clawdbot@${INST}..."
  systemctl restart "clawdbot@${INST}"
  sleep 3

  # ── Verify it started ──
  if systemctl is-active --quiet "clawdbot@${INST}"; then
    log "  clawdbot@${INST}: RUNNING"
  else
    log "  clawdbot@${INST}: FAILED TO START"
    log "  Check: journalctl -u clawdbot@${INST} -n 30 --no-pager"
  fi
done

# ─── Summary ──────────────────────────────────────────────────────────────────
log ""
log "═══════════════════════════════════════════════════"
log "  DISCORD SETUP COMPLETE"
log "═══════════════════════════════════════════════════"
log ""
log "Instance status:"
for i in 1 2 3; do
  STATUS=$(systemctl is-active "clawdbot@${i}" 2>/dev/null || echo "unknown")
  log "  clawdbot@${i}: ${STATUS}"
done

log ""
log "All 3 bots should appear ONLINE in your Discord server within 10 seconds."
log ""
log "Test in Discord:"
log "  #research  → @Clawdbot-Research Hello, are you online?"
log "  #ops       → @Clawdbot-Ops What's your status?"
log "  #strategy  → @Clawdbot-Strategy Give me a test response."
log ""
log "View logs:"
log "  journalctl -u clawdbot@1 -f   # Research bot"
log "  journalctl -u clawdbot@2 -f   # Ops bot"
log "  journalctl -u clawdbot@3 -f   # Strategy bot"
log ""
log "Full log saved to: ${LOG_FILE}"
