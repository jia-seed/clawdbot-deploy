#!/usr/bin/env bash
# multi_clawdbot_config.sh — Configure a specific Clawdbot instance
# Usage: sudo ./multi_clawdbot_config.sh <instance_number> [action]
#
# Actions:
#   onboard   — Run the clawdbot onboard wizard (default)
#   setkey    — Set/update ANTHROPIC_API_KEY interactively
#   env       — Open .env in $EDITOR for manual editing
#   restart   — Restart the instance service
#   status    — Show instance status and recent logs
#   logs      — Tail live logs
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
BASE_DIR="/opt"
CLAWDBOT_USER="clawdbot"
CLAWDBOT_GROUP="clawdbot"
BASE_PORT=18789

# ─── Argument parsing ────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: sudo $0 <instance_number> [action]

  instance_number   1, 2, 3, etc.

Actions:
  onboard   Run clawdbot onboard wizard (default)
  setkey    Set/update ANTHROPIC_API_KEY
  env       Edit .env file manually
  restart   Restart the systemd service
  status    Show service status + recent logs
  logs      Tail live logs (Ctrl-C to stop)
  stop      Stop the instance
  start     Start the instance

Examples:
  sudo $0 1              # onboard instance 1
  sudo $0 2 setkey       # set API key for instance 2
  sudo $0 3 restart      # restart instance 3
  sudo $0 1 logs         # tail instance 1 logs
EOF
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

INSTANCE="$1"
ACTION="${2:-onboard}"

# Validate instance number
if ! [[ "$INSTANCE" =~ ^[0-9]+$ ]] || [[ "$INSTANCE" -lt 1 ]]; then
  echo "ERROR: Instance number must be a positive integer." >&2
  exit 1
fi

INST_DIR="${BASE_DIR}/clawdbot-${INSTANCE}"
ENV_FILE="${INST_DIR}/.env"
SERVICE="clawdbot@${INSTANCE}"
PORT=$((BASE_PORT + INSTANCE - 1))

# Verify instance directory exists
if [[ ! -d "$INST_DIR" ]]; then
  echo "ERROR: Instance directory ${INST_DIR} does not exist." >&2
  echo "Run deploy_clawdbot_vm.sh first, or create it manually." >&2
  exit 1
fi

# ─── Helper functions ─────────────────────────────────────────────────────────
set_env_var() {
  local key="$1" value="$2" file="$3"
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    # Replace existing value (handles commented-out lines too)
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  elif grep -q "^# *${key}=" "$file" 2>/dev/null; then
    # Uncomment and set
    sed -i "s|^# *${key}=.*|${key}=${value}|" "$file"
  else
    # Append
    echo "${key}=${value}" >> "$file"
  fi
}

fix_permissions() {
  chown -R "${CLAWDBOT_USER}:${CLAWDBOT_GROUP}" "$INST_DIR"
  chmod 700 "$INST_DIR"
  chmod 600 "$ENV_FILE"
}

# ─── Actions ──────────────────────────────────────────────────────────────────
case "$ACTION" in

  onboard)
    echo "═══════════════════════════════════════════"
    echo "  Clawdbot Onboard — Instance #${INSTANCE}"
    echo "  Dir:  ${INST_DIR}"
    echo "  Port: ${PORT}"
    echo "═══════════════════════════════════════════"
    echo ""

    # Run onboard as the clawdbot user in the instance directory
    cd "$INST_DIR"
    sudo -u "$CLAWDBOT_USER" \
      --preserve-env=HOME \
      bash -c "cd '${INST_DIR}' && CLAWDBOT_CONFIG_DIR='${INST_DIR}' clawdbot onboard --install-daemon"

    fix_permissions

    echo ""
    echo "Onboarding complete. Restarting ${SERVICE}..."
    systemctl restart "$SERVICE"
    sleep 2
    systemctl status "$SERVICE" --no-pager -l || true
    ;;

  setkey)
    echo "═══════════════════════════════════════════"
    echo "  Set API Key — Instance #${INSTANCE}"
    echo "═══════════════════════════════════════════"
    echo ""

    # Read key securely (no echo)
    read -rsp "Enter ANTHROPIC_API_KEY for instance ${INSTANCE}: " API_KEY
    echo ""

    if [[ -z "$API_KEY" ]]; then
      echo "ERROR: API key cannot be empty." >&2
      exit 1
    fi

    # Basic format validation
    if [[ ! "$API_KEY" =~ ^sk-ant- ]]; then
      echo "WARNING: Key doesn't start with 'sk-ant-'. Proceeding anyway..."
    fi

    set_env_var "ANTHROPIC_API_KEY" "$API_KEY" "$ENV_FILE"
    fix_permissions

    echo "API key set for instance ${INSTANCE}."
    echo ""
    read -rp "Restart ${SERVICE} now? [Y/n] " RESTART
    if [[ "${RESTART,,}" != "n" ]]; then
      systemctl restart "$SERVICE"
      sleep 2
      systemctl status "$SERVICE" --no-pager -l || true
    fi
    ;;

  env)
    echo "Opening ${ENV_FILE} in editor..."
    fix_permissions
    "${EDITOR:-nano}" "$ENV_FILE"
    fix_permissions
    echo ""
    read -rp "Restart ${SERVICE} now? [Y/n] " RESTART
    if [[ "${RESTART,,}" != "n" ]]; then
      systemctl restart "$SERVICE"
      sleep 2
      systemctl status "$SERVICE" --no-pager -l || true
    fi
    ;;

  restart)
    echo "Restarting ${SERVICE}..."
    systemctl restart "$SERVICE"
    sleep 2
    systemctl status "$SERVICE" --no-pager -l || true
    ;;

  start)
    echo "Starting ${SERVICE}..."
    systemctl start "$SERVICE"
    sleep 2
    systemctl status "$SERVICE" --no-pager -l || true
    ;;

  stop)
    echo "Stopping ${SERVICE}..."
    systemctl stop "$SERVICE"
    echo "${SERVICE} stopped."
    ;;

  status)
    echo "═══════════════════════════════════════════"
    echo "  Status — Instance #${INSTANCE}"
    echo "  Dir:  ${INST_DIR}"
    echo "  Port: ${PORT}"
    echo "═══════════════════════════════════════════"
    echo ""
    systemctl status "$SERVICE" --no-pager -l || true
    echo ""
    echo "── Recent logs (last 25 lines) ──"
    journalctl -u "$SERVICE" -n 25 --no-pager || true
    echo ""
    echo "── Port check ──"
    ss -tlnp | grep ":${PORT}" || echo "  Port ${PORT} not listening."
    echo ""
    echo "── Memory usage ──"
    systemctl show "$SERVICE" -p MemoryCurrent --value 2>/dev/null || echo "  N/A"
    ;;

  logs)
    echo "Tailing logs for ${SERVICE} (Ctrl-C to stop)..."
    journalctl -u "$SERVICE" -f
    ;;

  *)
    echo "ERROR: Unknown action '${ACTION}'" >&2
    usage
    ;;
esac
