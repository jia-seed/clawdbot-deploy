# Mac Node Setup — Connecting Your Mac to a Clawdbot Gateway

This guide explains how to install the clawdbot node app on a Mac, pair it to a remote clawdbot gateway (e.g. cornbread on the Hetzner VM), and make the connection persistent across reboots.

## Architecture

```
┌─────────────────────┐         SSH Tunnel          ┌──────────────────────────┐
│      Your Mac       │ ◄──────────────────────────► │    Hetzner VM            │
│                     │    localhost:18789            │    91.98.29.37           │
│  clawdbot node host │ ◄── WebSocket ──►            │                          │
│  (launchd service)  │                              │  clawdbot gateway        │
│                     │                              │  (cornbread, port 18789) │
│  SSH tunnel         │                              │                          │
│  (launchd service)  │                              │  Discord plugin ◄──► Discord
└─────────────────────┘                              └──────────────────────────┘
```

**How it works:**

1. The clawdbot **gateway** runs on the VM and binds to `127.0.0.1:18789` (loopback only).
2. A persistent **SSH tunnel** forwards `localhost:18789` on your Mac to `127.0.0.1:18789` on the VM.
3. The clawdbot **node host** on your Mac connects to the gateway via this tunnel over WebSocket.
4. Once paired, the gateway can invoke commands on your Mac (shell exec, browser control, etc.).
5. Users on Discord talk to the bot, which can then run commands on your Mac through the node.

## Prerequisites

- macOS with Homebrew
- Node.js 22+ (`node --version`)
- SSH key access to the VM (`ssh root@91.98.29.37` should work without a password prompt)

## Step 1: Install Clawdbot CLI

```bash
npm install -g clawdbot
clawdbot --version  # should print 2026.1.24-3 or later
```

## Step 2: Set Up the Persistent SSH Tunnel

The gateway binds to loopback on the VM, so your Mac needs an SSH tunnel to reach it.

Copy the provided plist or create it:

```bash
cp config/mac-node/com.clawdbot.tunnel.plist ~/Library/LaunchAgents/
```

Or create `~/Library/LaunchAgents/com.clawdbot.tunnel.plist` manually — see `config/mac-node/com.clawdbot.tunnel.plist` for the template.

**Key settings in the plist:**
- `-N` — no remote command, just forward ports
- `-L 18789:127.0.0.1:18789` — forward local port 18789 to the VM's gateway port
- `ServerAliveInterval=30` — send keepalive every 30s to prevent idle disconnects
- `ServerAliveCountMax=3` — drop connection after 3 missed keepalives (90s)
- `ExitOnForwardFailure=yes` — fail immediately if the port forward can't bind
- `KeepAlive=true` — launchd will restart the tunnel if it dies
- `RunAtLoad=true` — starts automatically on login

Load it:

```bash
launchctl load ~/Library/LaunchAgents/com.clawdbot.tunnel.plist
```

Verify:

```bash
lsof -i :18789  # should show ssh listening
```

## Step 3: Install the Clawdbot Node Host

This registers your Mac as a "node" with the gateway, giving it `browser` and `system` capabilities.

```bash
clawdbot node install --host 127.0.0.1 --port 18789 --display-name "audreys-mac"
```

This creates `~/Library/LaunchAgents/com.clawdbot.node.plist` and starts the service automatically.

The node will connect to the gateway through the SSH tunnel and auto-pair on first connection.

Verify from the gateway (on the VM):

```bash
ssh root@91.98.29.37
HOME=/opt/clawdbot-1 CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json \
  clawdbot nodes status
```

You should see your Mac listed as `paired · connected`.

## Step 4: Configure Exec Approvals

By default, the node host blocks all remote command execution. You need to allowlist which binaries the gateway can invoke.

```bash
clawdbot approvals allowlist add --agent "*" "/usr/bin/*"
clawdbot approvals allowlist add --agent "*" "/bin/*"
clawdbot approvals allowlist add --agent "*" "/usr/sbin/*"
clawdbot approvals allowlist add --agent "*" "/opt/homebrew/bin/*"
clawdbot approvals allowlist add --agent "*" "/usr/local/bin/*"
```

Or copy the reference approvals file:

```bash
cp config/mac-node/exec-approvals.json ~/.clawdbot/exec-approvals.json
```

Check current approvals:

```bash
clawdbot approvals get
```

## Persistence Summary

Two launchd services keep everything alive:

| Service | Plist | What it does | Restart behavior |
|---------|-------|--------------|------------------|
| `com.clawdbot.tunnel` | `~/Library/LaunchAgents/com.clawdbot.tunnel.plist` | SSH tunnel `localhost:18789` → VM `91.98.29.37:18789` | `KeepAlive=true` — launchd restarts on crash/disconnect |
| `com.clawdbot.node` | `~/Library/LaunchAgents/com.clawdbot.node.plist` | Clawdbot node host connecting to gateway | `KeepAlive=true` — launchd restarts on crash |

Both start automatically on login (`RunAtLoad=true`) and restart if they die.

## Managing the Services

```bash
# Check status
launchctl list | grep clawdbot

# View logs
tail -f /tmp/clawdbot-tunnel.log                    # tunnel
tail -f ~/.clawdbot/logs/node.log                    # node host

# Restart
launchctl kickstart -k gui/$(id -u)/com.clawdbot.tunnel
launchctl kickstart -k gui/$(id -u)/com.clawdbot.node

# Stop
launchctl unload ~/Library/LaunchAgents/com.clawdbot.tunnel.plist
launchctl unload ~/Library/LaunchAgents/com.clawdbot.node.plist

# Start
launchctl load ~/Library/LaunchAgents/com.clawdbot.tunnel.plist
launchctl load ~/Library/LaunchAgents/com.clawdbot.node.plist
```

## Troubleshooting

**Node shows "not connected" on gateway:**
1. Check tunnel: `lsof -i :18789` — if empty, the tunnel is down
2. Check node logs: `tail -20 ~/.clawdbot/logs/node.log`
3. Restart both: `launchctl kickstart -k gui/$(id -u)/com.clawdbot.tunnel && sleep 3 && launchctl kickstart -k gui/$(id -u)/com.clawdbot.node`

**"needs approval" when running commands:**
- Exec approvals are empty. Run the `clawdbot approvals allowlist add` commands from Step 4.

**Tunnel port already in use:**
- Kill stale SSH: `pkill -f "ssh -N.*18789"` then restart the tunnel service.

**Gateway not running on VM:**
- Check: `ssh root@91.98.29.37 "systemctl status clawdbot@1"`
- Restart: `ssh root@91.98.29.37 "systemctl restart clawdbot@1"`

## Connecting to Other Instances

To pair with ricebread (instance 2, port 18790) or ubebread (instance 3, port 18795), create additional tunnel + node pairs with different ports:

```bash
# Example for ricebread
# Tunnel plist: -L 18790:127.0.0.1:18790
# Node: clawdbot node install --host 127.0.0.1 --port 18790 --display-name "audreys-mac"
```
