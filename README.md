# Clawdbot 3-Instance VM Deployment

Deploy Claude Code (Clawdbot) AI agents on a Hetzner Cloud server and connect them to Discord.

---

## Repository Structure

```
jiawdbots/
├── README.md                 # this file - vm deployment guide
├── docs/
│   ├── CLAUDE_CODE_DISCORD_SETUP.md   # complete discord + github setup
│   ├── DISCORD_BOT_SETUP.md           # detailed discord bot guide
│   ├── discord_setup_guide.md         # quick discord setup
│   ├── SHARED_MEMORY.md               # multi-bot memory sharing
│   ├── CUSTOM_CHECKINS.md             # scheduled check-ins setup
│   └── GOOGLE_WORKSPACE_SETUP.md     # gmail & calendar integration
├── scripts/
│   ├── deploy_clawdbot_vm.sh          # main vm deployment script
│   ├── automate_discord_setup.sh      # discord automation
│   ├── mac_tunnel_manager.sh          # ssh tunnel helper
│   ├── multi_clawdbot_config.sh       # multi-instance config
│   ├── setup_shared_memory.sh         # shared memory setup
│   ├── setup_custom_checkins.sh       # check-ins automation
│   └── sync-memory.sh                 # memory sync script
└── config/
    └── clawdbot_roles.json            # bot persona configs
```

---

## Quick Links

- [Discord + GitHub Setup](docs/CLAUDE_CODE_DISCORD_SETUP.md) - start here for full setup
- [Discord Bot Setup](docs/DISCORD_BOT_SETUP.md) - detailed discord guide
- [Shared Memory](docs/SHARED_MEMORY.md) - multi-bot memory sharing
- [Google Workspace (Gmail & Calendar)](docs/GOOGLE_WORKSPACE_SETUP.md) - email & calendar integration

---

## Overview

Three independent Clawdbot instances on a Hetzner Cloud ARM server (~€7.49/month), connected to Discord as specialized bots (Research, Ops, Strategy).

---

## Table of Contents
1. [What We Built](#what-we-built)
2. [Prerequisites](#prerequisites)
3. [Step 1: Local Setup (Mac)](#step-1-local-setup-mac)
4. [Step 2: Create the Hetzner VM](#step-2-create-the-hetzner-vm)
5. [Step 3: Deploy Clawdbot](#step-3-deploy-clawdbot)
6. [Step 4: Set API Keys & Start](#step-4-set-api-keys--start)
7. [Step 5: Clawdbot Onboarding](#step-5-clawdbot-onboarding)
8. [Step 6: Discord Integration](#step-6-discord-integration)
9. [Step 7: Access Your Instances](#step-7-access-your-instances)
10. [Architecture Overview](#architecture-overview)
11. [Management Commands](#management-commands)
12. [What Each Script Does](#what-each-script-does)
13. [Security Model](#security-model)
14. [Costs](#costs)
15. [Common Errors & Fixes](#common-errors--fixes)
16. [Shared Memory System](#shared-memory-system)
17. [Google Workspace (Gmail & Calendar)](#google-workspace-gmail--calendar)

---

## What We Built

```
┌──────────────────────────────────────────────────────────┐
│  Hetzner VM (Ubuntu 24.04 ARM)  ·  CAX21                │
│  4 vCPU · 8GB RAM · 80GB SSD                            │
│                                                          │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐     │
│  │ clawdbot@1   │ │ clawdbot@2   │ │ clawdbot@3   │     │
│  │ :18789       │ │ :18790       │ │ :18795       │     │
│  │ @cornbread   │ │ @ricebread   │ │ @ubebread    │     │
│  │ Research     │ │ Ops          │ │ Strategy     │     │
│  │ ~350MB RAM   │ │ ~340MB RAM   │ │ ~350MB RAM   │     │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘     │
│         │                │                │              │
│         └──── Discord WebSocket (outbound) ┘             │
│         └──────── 127.0.0.1 only (web UI) ─┘            │
│                                                          │
│  UFW Firewall: DENY all inbound except SSH (22)          │
└──────────────────────┬───────────────────────────────────┘
                       │ SSH tunnel (web UI only)
              ┌────────┴────────┐
              │   Your Laptop   │
              │  localhost:8081 │
              │  localhost:8082 │
              │  localhost:8083 │
              └─────────────────┘
```

Three isolated Clawdbot processes, each with:
- Its own directory, `.env` config, `.clawdbot/` state dir, and port
- A Discord bot connection (outbound WebSocket — no inbound ports needed)
- A systemd service that auto-starts on boot and auto-restarts on crash
- A 2GB memory ceiling
- Zero public network exposure

---

## Prerequisites

- A Mac (or any machine with a terminal)
- A Hetzner Cloud account (https://console.hetzner.cloud)
- A Hetzner API token (project → Security → API Tokens → Read & Write)
- An Anthropic API key (`sk-ant-...`) from https://console.anthropic.com/settings/keys
- 3 Discord bot tokens (see [Step 6](#step-6-discord-integration))

---

## Step 1: Local Setup (Mac)

### Generate an SSH key
```bash
ssh-keygen -t ed25519 -C "clawdbot-vm" -f ~/.ssh/id_ed25519 -N ""
```

### Install the Hetzner CLI
```bash
brew install hcloud
```

### Authenticate with your Hetzner API token
```bash
HCLOUD_TOKEN=YOUR_HETZNER_TOKEN hcloud context create clawdbot --token-from-env
```

---

## Step 2: Create the Hetzner VM

**Important:** Use CAX21 (8GB RAM), not CAX11 (4GB). Clawdbot uses ~350MB per instance at steady state but spikes to ~500MB+ during startup. 3 instances on 4GB causes OOM crashes.

### Upload your SSH public key
```bash
hcloud ssh-key create --name clawdbot-vm --public-key-from-file ~/.ssh/id_ed25519.pub
```

### Create the server
```bash
hcloud server create \
  --name clawdbot-vm \
  --type cax21 \
  --image ubuntu-24.04 \
  --ssh-key clawdbot-vm \
  --location nbg1
```

| Spec | Value |
|------|-------|
| Type | CAX21 (ARM64) |
| CPU | 4 shared vCPU (Ampere Altra) |
| RAM | 8 GB |
| Disk | 80 GB local SSD |
| OS | Ubuntu 24.04 LTS |
| Location | nbg1 (Nuremberg, Germany) |
| Cost | **~€7.49/month** |

### Verify SSH access
```bash
# Wait ~15 seconds after creation for boot
ssh -o StrictHostKeyChecking=accept-new root@YOUR_VM_IP "echo 'SSH OK'"
```

---

## Step 3: Deploy Clawdbot

### Upload and run the deploy script
```bash
scp deploy_clawdbot_vm.sh multi_clawdbot_config.sh root@YOUR_VM_IP:/root/
ssh root@YOUR_VM_IP "chmod +x /root/*.sh && bash /root/deploy_clawdbot_vm.sh"
```

**What this does:**
```
[1/8] Updating system packages           → apt update + upgrade
[2/8] Installing Node.js 22.x            → v22 LTS via NodeSource (clawdbot requires >=22)
[3/8] Installing utilities (ufw, jq)     → firewall + JSON tool
[4/8] Creating system user 'clawdbot'    → non-root service account
[5/8] Installing clawdbot globally        → npm install -g clawdbot@latest
[6/8] Setting up 3 instance directories  → /opt/clawdbot-{1,2,3} with .env files
[7/8] Creating systemd service template  → clawdbot@{1,2,3}.service enabled
[8/8] Configuring firewall (ufw)         → deny all inbound except SSH
```

**Critical:** Clawdbot requires **Node.js 22+**. The deploy script installs Node 22 from the NodeSource repository. If you see `clawdbot requires Node >=22.0.0`, your Node version is too old.

---

## Step 4: Set API Keys & Start

### Set the Anthropic API key on all 3 instances
```bash
ssh root@YOUR_VM_IP "for i in 1 2 3; do \
  sed -i \"s|sk-ant-REPLACE_ME_INSTANCE_\${i}|YOUR_ANTHROPIC_API_KEY|\" \
  /opt/clawdbot-\${i}/.env; \
done"
```

**Do not start the services yet** — you need to run the onboarding step first (Step 5).

---

## Step 5: Clawdbot Onboarding

Each instance needs to be initialized with `clawdbot onboard` before the gateway will start. This creates the config file, workspace directory, and session store.

### Run onboard for all 3 instances
```bash
ssh root@YOUR_VM_IP 'for i in 1 2 3; do
  PORT=$(grep CLAWDBOT_PORT /opt/clawdbot-$i/.env | cut -d= -f2)
  echo "=== Onboarding Instance $i (port $PORT) ==="
  HOME=/opt/clawdbot-$i \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-$i/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-$i/.clawdbot/clawdbot.json \
  clawdbot onboard \
    --non-interactive \
    --accept-risk \
    --mode local \
    --workspace /opt/clawdbot-$i/workspace \
    --anthropic-api-key "YOUR_ANTHROPIC_API_KEY" \
    --gateway-port $PORT \
    --gateway-bind loopback \
    --gateway-auth off \
    --skip-channels \
    --skip-skills \
    --skip-health \
    --skip-ui \
    --skip-daemon
  chown -R clawdbot:clawdbot /opt/clawdbot-$i
done'
```

**Key flags explained:**
- `--non-interactive --accept-risk` — run without prompts (required for automation)
- `--mode local` — gateway runs locally on the VM
- `--gateway-bind loopback` — bind to 127.0.0.1 only
- `--skip-daemon` — we use our own systemd service, not clawdbot's built-in daemon

---

## Step 6: Discord Integration

### 6a. Create 3 Discord Bot Applications

Repeat for each bot at https://discord.com/developers/applications:

1. **New Application** → name it (e.g., `Clawdbot-Research`, `Clawdbot-Ops`, `Clawdbot-Strategy`)
2. **Bot tab** → click "Reset Token" → **copy the token immediately** (shown only once)
3. **Bot tab → Privileged Gateway Intents** → toggle ON all three:
   - [x] PRESENCE INTENT
   - [x] SERVER MEMBERS INTENT
   - [x] **MESSAGE CONTENT INTENT** (critical — without this, bots can't read messages)
4. **Click "Save Changes"**
5. **OAuth2 tab → URL Generator**:
   - Scopes: `bot`, `applications.commands`
   - Permissions: Send Messages, Read Message History, View Channels, Embed Links, Attach Files, Add Reactions
6. Copy the generated URL → paste in browser → select your server → Authorize

### 6b. Get Server & Channel IDs

1. Discord Settings → Advanced → enable **Developer Mode**
2. Right-click **server name** → Copy Server ID
3. Right-click **channel name** → Copy Channel ID

### 6c. Enable Discord Plugin & Add Channels

```bash
ssh root@YOUR_VM_IP 'TOKENS=("TOKEN_1" "TOKEN_2" "TOKEN_3")
for i in 0 1 2; do
  INST=$((i+1))
  echo "=== Instance $INST ==="
  HOME=/opt/clawdbot-$INST \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-$INST/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-$INST/.clawdbot/clawdbot.json \
  clawdbot plugins enable discord

  HOME=/opt/clawdbot-$INST \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-$INST/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-$INST/.clawdbot/clawdbot.json \
  clawdbot channels add --channel discord --token "${TOKENS[$i]}"

  chown -R clawdbot:clawdbot /opt/clawdbot-$INST
done'
```

### 6d. Set Group Policy to Open

By default, Clawdbot sets `groupPolicy: allowlist` which silently drops all messages in channels not explicitly allowlisted. You must change this to `open`:

```bash
ssh root@YOUR_VM_IP 'for i in 1 2 3; do
  HOME=/opt/clawdbot-$i \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-$i/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-$i/.clawdbot/clawdbot.json \
  clawdbot config set channels.discord.groupPolicy open
  chown -R clawdbot:clawdbot /opt/clawdbot-$i
done'
```

**This is the most common reason bots appear online but don't respond.**

### 6e. Fix Permissions & Start (Staggered)

After running commands as root, file ownership gets changed. Always fix permissions before starting:

```bash
ssh root@YOUR_VM_IP 'for i in 1 2 3; do
  chown -R clawdbot:clawdbot /opt/clawdbot-$i
  find /opt/clawdbot-$i -type d -exec chmod 700 {} \;
  find /opt/clawdbot-$i -type f -exec chmod 600 {} \;
done

# Stagger startup — instances spike memory during init
systemctl start clawdbot@1 && sleep 35
systemctl start clawdbot@2 && sleep 35
systemctl start clawdbot@3 && sleep 35

for i in 1 2 3; do
  echo "Instance $i: $(systemctl is-active clawdbot@$i)"
done'
```

### 6f. Verify Discord Connection

```bash
ssh root@YOUR_VM_IP 'for i in 1 2 3; do
  echo "=== Instance $i ==="
  journalctl -u clawdbot@$i -n 5 --no-pager -l | grep "discord.*logged"
done'
```

Expected:
```
[discord] logged in to discord as 1476529827350843492
```

### 6g. Test: Send a Bot Message

```bash
ssh root@YOUR_VM_IP 'HOME=/opt/clawdbot-1 \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json \
  clawdbot message send --channel discord --target YOUR_CHANNEL_ID --message "hello from clawdbot"'
```

Then @mention the bot in Discord:
```
@YourBotName hello
```

---

## Step 7: Access Your Instances

Discord integration does **not** require SSH tunnels — bots connect outbound to Discord's servers. Tunnels are only needed for the Clawdbot web dashboard.

### SSH tunnel (web dashboard only)
```bash
ssh -L 8081:127.0.0.1:18789 \
    -L 8082:127.0.0.1:18790 \
    -L 8083:127.0.0.1:18795 \
    root@YOUR_VM_IP
```

| Instance | Local URL |
|----------|-----------|
| #1 | http://localhost:8081 |
| #2 | http://localhost:8082 |
| #3 | http://localhost:8083 |

---

## Architecture Overview

### File layout on the VM

```
/opt/
├── clawdbot-1/                     # Instance 1 (port 18789)
│   ├── .env                        # API key + port config (mode 600)
│   ├── .clawdbot/
│   │   ├── clawdbot.json           # Main config (plugins, channels, skills)
│   │   ├── credentials/            # OAuth/token storage
│   │   └── agents/main/sessions/   # Conversation sessions
│   └── workspace/                  # Agent workspace
├── clawdbot-2/                     # Instance 2 (port 18790)
│   └── ...
├── clawdbot-3/                     # Instance 3 (port 18795)
│   └── ...
├── clawdbot-shared/                # Shared config across instances
│   └── .config/gogcli/             # Google Workspace credentials + tokens
│       ├── credentials.json
│       └── keyring/
└── clawdbot-memory/                # Shared git-backed memory

/etc/systemd/system/
└── clawdbot@.service               # Template unit (one file, N instances)
```

### Systemd service template

The service file uses these critical environment variables:
```ini
Environment=HOME=/opt/clawdbot-%i
Environment=CLAWDBOT_STATE_DIR=/opt/clawdbot-%i/.clawdbot
Environment=CLAWDBOT_CONFIG_PATH=/opt/clawdbot-%i/.clawdbot/clawdbot.json
EnvironmentFile=/opt/clawdbot-%i/.env

ExecStart=/usr/bin/clawdbot gateway --port ${CLAWDBOT_PORT}
```

**Key points:**
- `HOME` must point to the instance directory (clawdbot resolves `~/.clawdbot` from HOME)
- `CLAWDBOT_STATE_DIR` and `CLAWDBOT_CONFIG_PATH` isolate each instance's state
- `ProtectHome=no` is required (HOME points to /opt, not /home)
- The gateway command is `clawdbot gateway --port PORT`, not `clawdbot start`

### Process model
- **User:** `clawdbot` (system account, no login shell, no SSH access)
- **Process:** `clawdbot gateway --port PORT`
- **Supervisor:** systemd (auto-restart on crash, 10s backoff)
- **Memory limit:** 2GB max per instance (`MemoryMax=2G`)
- **Logging:** journald (no separate log files to rotate)

### Port allocation

Clawdbot spawns derived ports for browser control and canvas. Space ports 5+ apart to avoid collisions:

| Instance | Gateway Port | Browser Port (auto) | Notes |
|----------|-------------|--------------------|----|
| #1 | 18789 | 18791 | Default |
| #2 | 18790 | 18792 | Default |
| #3 | 18795 | 18797 | Moved to avoid collision with instance 1's browser port |

---

## Management Commands

### Service control
```bash
# Status
ssh root@YOUR_VM_IP "systemctl status clawdbot@1"

# Restart one instance
ssh root@YOUR_VM_IP "systemctl restart clawdbot@1"

# Stop one instance
ssh root@YOUR_VM_IP "systemctl stop clawdbot@2"

# Restart all (staggered)
ssh root@YOUR_VM_IP "for i in 1 2 3; do systemctl restart clawdbot@\$i; sleep 10; done"
```

### Logs
```bash
# Live tail for instance 1
ssh root@YOUR_VM_IP "journalctl -u clawdbot@1 -f"

# Last 100 lines
ssh root@YOUR_VM_IP "journalctl -u clawdbot@1 -n 100 --no-pager"

# All instances interleaved
ssh root@YOUR_VM_IP "journalctl -u 'clawdbot@*' -f"

# Errors only
ssh root@YOUR_VM_IP "journalctl -u clawdbot@1 -p err"

# Clawdbot's own log (more detailed)
ssh root@YOUR_VM_IP "HOME=/opt/clawdbot-1 CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json clawdbot logs"
```

### Health checks
```bash
# Channel status (is Discord connected?)
ssh root@YOUR_VM_IP "HOME=/opt/clawdbot-1 CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json clawdbot channels status"

# Full doctor check
ssh root@YOUR_VM_IP "HOME=/opt/clawdbot-1 CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json clawdbot doctor"

# Memory per instance
ssh root@YOUR_VM_IP "for i in 1 2 3; do echo \"Instance \$i: \$(($(systemctl show clawdbot@\$i -p MemoryCurrent --value) / 1048576))MB\"; done"
```

### Update clawdbot
```bash
ssh root@YOUR_VM_IP "npm install -g clawdbot@latest && for i in 1 2 3; do systemctl restart clawdbot@\$i; sleep 10; done"
```

### Scaling to N instances
```bash
ssh root@YOUR_VM_IP '
  INST=4; PORT=18800
  mkdir -p /opt/clawdbot-$INST
  cp /opt/clawdbot-1/.env /opt/clawdbot-$INST/.env
  sed -i "s/CLAWDBOT_PORT=.*/CLAWDBOT_PORT=$PORT/" /opt/clawdbot-$INST/.env
  # Run onboard, enable discord, set groupPolicy (same as Steps 5-6)
  chown -R clawdbot:clawdbot /opt/clawdbot-$INST
  systemctl enable --now clawdbot@$INST
'
```

### Destroy everything
```bash
# Delete the VM entirely (stops billing)
hcloud server delete clawdbot-vm

# Or just stop instances but keep the VM
ssh root@YOUR_VM_IP "for i in 1 2 3; do systemctl stop clawdbot@\$i; done"
```

---

## What Each Script Does

### `deploy_clawdbot_vm.sh` — Full automated setup

| Step | What | Why |
|------|------|-----|
| System update | `apt update && apt upgrade` | Patch security vulnerabilities on fresh image |
| Node.js 22 | NodeSource repo → `apt install nodejs` | Clawdbot requires Node.js >=22 |
| Utilities | `apt install ufw jq` | Firewall + JSON parsing for config |
| System user | `useradd --system clawdbot` | Services should never run as root |
| Sudoers | Limited `systemctl` permissions | Config helper can restart services without full root |
| Clawdbot | `npm install -g clawdbot@latest` | The actual application |
| Instance dirs | `/opt/clawdbot-{1,2,3}` with `.env` | Isolated config per instance |
| Permissions | `chmod 700` dirs, `chmod 600` .env | API keys readable only by owner |
| Systemd template | `clawdbot@.service` | One unit file serves all instances via `%i` substitution |
| Service enable | `systemctl enable clawdbot@{1,2,3}` | Auto-start on boot |
| Firewall | UFW deny all, allow SSH only | No clawdbot ports exposed to internet |

### `multi_clawdbot_config.sh` — Per-instance management

Wrapper script that takes an instance number and an action:
- `onboard` — runs `clawdbot onboard` as the clawdbot user in the correct directory
- `setkey` — securely prompts for API key (input hidden), writes to `.env`, offers to restart
- `env` — opens `.env` in your editor
- `restart` / `start` / `stop` — systemctl wrappers
- `status` — service status + last 25 log lines + port check + memory usage
- `logs` — live `journalctl` tail

---

## Security Model

| Layer | Protection |
|-------|-----------|
| **Network** | UFW denies all inbound except port 22 (SSH) |
| **Binding** | Clawdbot gateway listens on `127.0.0.1` only |
| **Discord** | Outbound WebSocket only — no inbound ports needed |
| **Access** | SSH tunnel required to reach web dashboard |
| **User** | Services run as `clawdbot` (no login shell, no SSH) |
| **Privileges** | `NoNewPrivileges=true` in systemd |
| **Filesystem** | `ProtectSystem=strict`, `PrivateTmp=true` |
| **Secrets** | `.env` files and `.clawdbot/` dir mode `600`/`700`, owned by `clawdbot:clawdbot` |
| **Resources** | `MemoryMax=2G` per instance — OOM-killed if exceeded |
| **Recovery** | `Restart=always` with 10s backoff |

---

## Costs

| Item | Cost |
|------|------|
| Hetzner CAX21 (4 vCPU, 8GB, 80GB SSD) | **€7.49/month** (~$8.10) |
| Anthropic API usage | Per-token (varies by usage) |
| Total infrastructure | **~$8/month** |

---

## Common Errors & Fixes

### `clawdbot requires Node >=22.0.0`
**Cause:** Clawdbot latest requires Node 22+. The deploy script originally installed Node 20.
**Fix:**
```bash
ssh root@YOUR_VM_IP '
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg --yes
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
  apt-get update -qq && apt-get install -y -qq nodejs
  node -v   # should show v22.x
  npm install -g clawdbot@latest
  systemctl daemon-reload
  for i in 1 2 3; do systemctl restart clawdbot@$i; sleep 10; done
'
```

### `error: unknown command 'start'`
**Cause:** The correct gateway command is `clawdbot gateway --port PORT`, not `clawdbot start`.
**Fix:** Update the systemd service `ExecStart` line:
```bash
ssh root@YOUR_VM_IP "sed -i 's|clawdbot start.*|clawdbot gateway --port \${CLAWDBOT_PORT}|' /etc/systemd/system/clawdbot@.service && systemctl daemon-reload"
```

### `Missing config. Run clawdbot setup`
**Cause:** The instance hasn't been onboarded. Clawdbot needs a `clawdbot.json` config file to start.
**Fix:** Run the onboard command (see [Step 5](#step-5-clawdbot-onboarding)).

### `FATAL ERROR: Reached heap limit Allocation failed - JavaScript heap out of memory`
**Cause:** Not enough RAM. Each Clawdbot instance uses ~350MB at steady state but spikes during startup. 3 instances on 4GB = OOM.
**Fix:** Upgrade to CAX21 (8GB):
```bash
hcloud server poweroff clawdbot-vm
hcloud server change-type clawdbot-vm cax21
hcloud server poweron clawdbot-vm
```
Also raise the systemd memory limit:
```bash
ssh root@YOUR_VM_IP "sed -i 's/MemoryMax=1G/MemoryMax=2G/' /etc/systemd/system/clawdbot@.service && systemctl daemon-reload"
```

### `Unknown channel: discord`
**Cause:** Discord is a plugin that must be enabled before it can be used as a channel.
**Fix:**
```bash
ssh root@YOUR_VM_IP 'HOME=/opt/clawdbot-1 \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json \
  clawdbot plugins enable discord'
```

### Bot is online in Discord but doesn't respond to messages
**Cause:** `groupPolicy` is set to `allowlist` (the default). Messages in channels not on the allowlist are silently dropped.
**Fix:**
```bash
ssh root@YOUR_VM_IP 'HOME=/opt/clawdbot-1 \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json \
  clawdbot config set channels.discord.groupPolicy open
  chown -R clawdbot:clawdbot /opt/clawdbot-1
  systemctl restart clawdbot@1'
```

### Bot online but messages not received at all (no log entries)
**Cause:** MESSAGE CONTENT INTENT not enabled in Discord Developer Portal, or enabled but not saved.
**Fix:**
1. Go to https://discord.com/developers/applications → your bot → Bot tab
2. Scroll to **Privileged Gateway Intents**
3. Toggle ON: PRESENCE INTENT, SERVER MEMBERS INTENT, **MESSAGE CONTENT INTENT**
4. **Click Save Changes** (easy to miss!)
5. Restart the clawdbot service

### `HTTP 401: authentication_error: invalid x-api-key`
**Cause:** The Anthropic API key in `.env` is invalid, expired, or has been rotated.
**Fix:**
```bash
ssh root@YOUR_VM_IP "for i in 1 2 3; do
  sed -i 's|ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=sk-ant-YOUR_NEW_KEY|' /opt/clawdbot-\$i/.env
  chown clawdbot:clawdbot /opt/clawdbot-\$i/.env
  systemctl restart clawdbot@\$i
  sleep 10
done"
```

### `EACCES: permission denied, open '/opt/clawdbot-1/.clawdbot/clawdbot.json'`
**Cause:** Running `clawdbot config set` or `clawdbot plugins enable` as root changes file ownership from `clawdbot` to `root`. The service then can't read its own config.
**Fix:** Always fix permissions after running any clawdbot CLI command as root:
```bash
ssh root@YOUR_VM_IP 'for i in 1 2 3; do
  chown -R clawdbot:clawdbot /opt/clawdbot-$i
  find /opt/clawdbot-$i -type d -exec chmod 700 {} \;
  find /opt/clawdbot-$i -type f -exec chmod 600 {} \;
  systemctl restart clawdbot@$i
  sleep 10
done'
```

### `Gateway failed to start: another gateway instance is already listening on ws://127.0.0.1:PORT`
**Cause:** Port collision. Clawdbot spawns derived ports for browser control (gateway_port + 2). Instance 1 on 18789 takes 18791 for browser, which collides with instance 3 if it's on 18791.
**Fix:** Space gateway ports 5+ apart:
```
Instance 1: 18789 (browser: 18791)
Instance 2: 18790 (browser: 18792)
Instance 3: 18795 (browser: 18797)  ← moved from 18791
```
```bash
ssh root@YOUR_VM_IP "sed -i 's/CLAWDBOT_PORT=18791/CLAWDBOT_PORT=18795/' /opt/clawdbot-3/.env && systemctl restart clawdbot@3"
```

### Service shows `activating` for a long time
**Cause:** Clawdbot takes 20-30 seconds to fully start (loading plugins, connecting to Discord, etc.). This is normal.
**Fix:** Wait 30-40 seconds after starting before checking. Don't start all 3 simultaneously — stagger by 30-35 seconds.

---

## Summary of Every Command Run

```bash
# === ON YOUR MAC ===

# 1. Generate SSH key
ssh-keygen -t ed25519 -C "clawdbot-vm" -f ~/.ssh/id_ed25519 -N ""

# 2. Install Hetzner CLI
brew install hcloud

# 3. Authenticate
HCLOUD_TOKEN=YOUR_TOKEN hcloud context create clawdbot --token-from-env

# 4. Upload SSH key to Hetzner
hcloud ssh-key create --name clawdbot-vm --public-key-from-file ~/.ssh/id_ed25519.pub

# 5. Create VM (use cax21 for 8GB RAM)
hcloud server create --name clawdbot-vm --type cax21 --image ubuntu-24.04 --ssh-key clawdbot-vm --location nbg1

# 6. Upload scripts
scp deploy_clawdbot_vm.sh multi_clawdbot_config.sh root@YOUR_VM_IP:/root/

# 7. Run deploy
ssh root@YOUR_VM_IP "chmod +x /root/*.sh && bash /root/deploy_clawdbot_vm.sh"

# 8. Set API keys
ssh root@YOUR_VM_IP "for i in 1 2 3; do sed -i \"s|sk-ant-REPLACE_ME_INSTANCE_\${i}|sk-ant-YOUR_KEY|\" /opt/clawdbot-\${i}/.env; done"

# 9. Onboard all 3 instances (see Step 5 for full command)

# 10. Enable Discord plugin + add tokens (see Step 6c)

# 11. Set groupPolicy to open (see Step 6d)

# 12. Fix permissions
ssh root@YOUR_VM_IP "for i in 1 2 3; do chown -R clawdbot:clawdbot /opt/clawdbot-\$i; done"

# 13. Start all instances (staggered)
ssh root@YOUR_VM_IP "systemctl start clawdbot@1 && sleep 35 && systemctl start clawdbot@2 && sleep 35 && systemctl start clawdbot@3"

# 14. Verify
ssh root@YOUR_VM_IP "for i in 1 2 3; do echo \"Instance \$i: \$(systemctl is-active clawdbot@\$i)\"; journalctl -u clawdbot@\$i -n 3 --no-pager -l | grep discord; done"

# 15. Test in Discord: @YourBotName hello
```

---

## Shared Memory System

The bots share a git-backed knowledge base at `/opt/clawdbot-memory/` that persists across crashes and restarts. Memories auto-sync to a private GitHub repo every 5 minutes.

**Quick setup:**
```bash
scp setup_shared_memory.sh sync-memory.sh root@YOUR_VM_IP:/root/
ssh root@YOUR_VM_IP "chmod +x /root/setup_shared_memory.sh /root/sync-memory.sh && bash /root/setup_shared_memory.sh"
```

See **[SHARED_MEMORY.md](SHARED_MEMORY.md)** for full documentation.

---

## Google Workspace (Gmail & Calendar)

The bots can read/send emails and manage Google Calendar via the bundled `gog` skill, which wraps [`gogcli`](https://github.com/steipete/gogcli).

| Instance | Bot | Default Google Account |
|----------|-----|------------------------|
| #1 | @cornbread | jiachiachen@gmail.com |
| #2 | @ricebread | audgeviolin07@gmail.com |
| #3 | @ubebread | jia@spreadjam.com |

**Quick setup:**
```bash
# Install gog binary
ssh root@YOUR_VM_IP 'curl -sL https://github.com/steipete/gogcli/releases/download/v0.11.0/gogcli_0.11.0_linux_arm64.tar.gz | tar xz -C /usr/local/bin && chmod +x /usr/local/bin/gog'

# Upload OAuth credentials (create at Google Cloud Console first)
scp client_secret_*.json root@YOUR_VM_IP:/tmp/client_secret.json
ssh root@YOUR_VM_IP "gog auth credentials set /tmp/client_secret.json"

# Authenticate each account (headless two-step flow)
ssh root@YOUR_VM_IP "GOG_KEYRING_PASSWORD=clawdbot-gog-keyring gog auth add user@gmail.com --services gmail,calendar --remote --step 1"
# Open URL in browser, authorize, copy redirect URL, then:
ssh root@YOUR_VM_IP "GOG_KEYRING_PASSWORD=clawdbot-gog-keyring gog auth add user@gmail.com --services gmail,calendar --remote --step 2 --auth-url 'REDIRECT_URL'"
```

**Test in Discord:**
```
@cornbread check my email from the last 24 hours
@ricebread what's on my calendar today?
```

See **[GOOGLE_WORKSPACE_SETUP.md](docs/GOOGLE_WORKSPACE_SETUP.md)** for the complete setup guide, troubleshooting, and how to add new accounts.
