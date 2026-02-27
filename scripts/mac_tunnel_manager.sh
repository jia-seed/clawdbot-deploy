#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# mac_tunnel_manager.sh — Manage SSH tunnels to 3 Clawdbot instances
#
# QUICK START (30 seconds):
#   chmod +x mac_tunnel_manager.sh
#   ./mac_tunnel_manager.sh up       # open all 3 tunnels
#   ./mac_tunnel_manager.sh status   # check health
#   ./mac_tunnel_manager.sh down     # close all tunnels
#
# Run on your Mac. Tunnels auto-reconnect on drop.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
VM_HOST="91.98.29.37"
VM_USER="root"
SSH_KEY="$HOME/.ssh/id_ed25519"
PID_DIR="$HOME/.clawdbot-tunnels"

# Port mappings: local_port → remote_port
declare -a LOCAL_PORTS=(8081 8082 8083)
declare -a REMOTE_PORTS=(18789 18790 18791)
declare -a LABELS=("Research" "Ops" "Strategy")

# SSH options for stable tunnels
SSH_OPTS=(
  -o "StrictHostKeyChecking=accept-new"
  -o "ServerAliveInterval=30"
  -o "ServerAliveCountMax=3"
  -o "ExitOnForwardFailure=yes"
  -o "ConnectTimeout=10"
  -o "TCPKeepAlive=yes"
  -i "$SSH_KEY"
)

# ─── Helpers ──────────────────────────────────────────────────────────────────
ensure_pid_dir() {
  mkdir -p "$PID_DIR"
}

pid_file() {
  echo "${PID_DIR}/tunnel-${1}.pid"
}

is_tunnel_alive() {
  local pf
  pf=$(pid_file "$1")
  if [[ -f "$pf" ]]; then
    local pid
    pid=$(cat "$pf")
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

port_in_use() {
  lsof -iTCP:"$1" -sTCP:LISTEN -t >/dev/null 2>&1
}

# ─── Commands ─────────────────────────────────────────────────────────────────
cmd_up() {
  ensure_pid_dir
  echo "══════════════════════════════════════════════"
  echo "  Clawdbot Tunnel Manager — Opening Tunnels"
  echo "══════════════════════════════════════════════"
  echo ""

  local all_ok=true

  for i in 0 1 2; do
    local inst=$((i + 1))
    local lport="${LOCAL_PORTS[$i]}"
    local rport="${REMOTE_PORTS[$i]}"
    local label="${LABELS[$i]}"
    local pf
    pf=$(pid_file "$inst")

    echo -n "  Instance ${inst} (${label}): localhost:${lport} → VM:${rport} ... "

    # Check if already running
    if is_tunnel_alive "$inst"; then
      echo "ALREADY UP (pid $(cat "$pf"))"
      continue
    fi

    # Check if port is occupied by something else
    if port_in_use "$lport"; then
      echo "FAILED — port ${lport} already in use"
      echo "    Kill it: lsof -iTCP:${lport} -sTCP:LISTEN -t | xargs kill"
      all_ok=false
      continue
    fi

    # Open the tunnel in background
    ssh -f -N \
      "${SSH_OPTS[@]}" \
      -L "${lport}:127.0.0.1:${rport}" \
      "${VM_USER}@${VM_HOST}"

    # Find the PID (most recent ssh process with this port forward)
    sleep 1
    local pid
    pid=$(lsof -iTCP:"${lport}" -sTCP:LISTEN -t 2>/dev/null | head -1 || echo "")

    if [[ -n "$pid" ]]; then
      echo "$pid" > "$pf"
      echo "UP (pid ${pid})"
    else
      echo "FAILED — could not establish tunnel"
      all_ok=false
    fi
  done

  echo ""
  if $all_ok; then
    echo "All tunnels open. Access:"
    echo "  http://localhost:8081  (Research)"
    echo "  http://localhost:8082  (Ops)"
    echo "  http://localhost:8083  (Strategy)"
  else
    echo "Some tunnels failed. Run './mac_tunnel_manager.sh status' for details."
  fi
  echo ""
}

cmd_down() {
  ensure_pid_dir
  echo "══════════════════════════════════════════════"
  echo "  Clawdbot Tunnel Manager — Closing Tunnels"
  echo "══════════════════════════════════════════════"
  echo ""

  for i in 0 1 2; do
    local inst=$((i + 1))
    local label="${LABELS[$i]}"
    local pf
    pf=$(pid_file "$inst")

    echo -n "  Instance ${inst} (${label}): "

    if is_tunnel_alive "$inst"; then
      local pid
      pid=$(cat "$pf")
      kill "$pid" 2>/dev/null
      rm -f "$pf"
      echo "STOPPED (was pid ${pid})"
    else
      rm -f "$pf"
      echo "NOT RUNNING"
    fi
  done

  echo ""
  echo "All tunnels closed."
  echo ""
}

cmd_status() {
  ensure_pid_dir
  echo "══════════════════════════════════════════════"
  echo "  Clawdbot Tunnel Manager — Status"
  echo "══════════════════════════════════════════════"
  echo ""
  printf "  %-4s %-12s %-22s %-8s %s\n" "#" "Role" "Mapping" "Status" "PID"
  printf "  %-4s %-12s %-22s %-8s %s\n" "──" "──────────" "────────────────────" "──────" "───"

  for i in 0 1 2; do
    local inst=$((i + 1))
    local lport="${LOCAL_PORTS[$i]}"
    local rport="${REMOTE_PORTS[$i]}"
    local label="${LABELS[$i]}"
    local mapping="localhost:${lport}→VM:${rport}"
    local status="DOWN"
    local pid="—"

    if is_tunnel_alive "$inst"; then
      status="UP"
      pid=$(cat "$(pid_file "$inst")")
    fi

    printf "  %-4s %-12s %-22s %-8s %s\n" "$inst" "$label" "$mapping" "$status" "$pid"
  done

  echo ""

  # Quick VM connectivity check
  echo -n "  VM connectivity (${VM_HOST}): "
  if ssh "${SSH_OPTS[@]}" -o "ConnectTimeout=5" "${VM_USER}@${VM_HOST}" "echo ok" 2>/dev/null | grep -q ok; then
    echo "REACHABLE"
  else
    echo "UNREACHABLE"
  fi
  echo ""
}

cmd_restart() {
  cmd_down
  sleep 1
  cmd_up
}

# ─── Main ─────────────────────────────────────────────────────────────────────
ACTION="${1:-help}"

case "$ACTION" in
  up|start|open)
    cmd_up
    ;;
  down|stop|close)
    cmd_down
    ;;
  status|check)
    cmd_status
    ;;
  restart|reconnect)
    cmd_restart
    ;;
  help|--help|-h)
    cat <<'EOF'
Clawdbot Tunnel Manager — Manage SSH tunnels to your Hetzner VM

Usage: ./mac_tunnel_manager.sh <command>

Commands:
  up        Open all 3 SSH tunnels (background, auto-keepalive)
  down      Close all tunnels
  status    Show tunnel status + VM connectivity
  restart   Close and re-open all tunnels

Port Mappings:
  localhost:8081  →  VM:18789  (Instance 1 — Research)
  localhost:8082  →  VM:18790  (Instance 2 — Ops)
  localhost:8083  →  VM:18791  (Instance 3 — Strategy)

After 'up', open in browser:
  http://localhost:8081
  http://localhost:8082
  http://localhost:8083

Note: Discord integration does NOT need tunnels.
Tunnels are only for the Clawdbot web dashboard.
EOF
    ;;
  *)
    echo "Unknown command: $ACTION"
    echo "Run './mac_tunnel_manager.sh help' for usage."
    exit 1
    ;;
esac
