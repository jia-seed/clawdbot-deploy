# Discord Bot Setup & Configuration for Clawdbot

Complete guide to creating, inviting, configuring, and managing 3 Clawdbot Discord bots on your server.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Create Discord Bot Applications](#step-1-create-discord-bot-applications)
4. [Set Up Your Discord Server](#step-2-set-up-your-discord-server)
5. [Get Server & Channel IDs](#step-3-get-server--channel-ids)
6. [Invite Bots to Your Server](#step-4-invite-bots-to-your-server)
7. [Connect Bots to Clawdbot on the VM](#step-5-connect-bots-to-clawdbot-on-the-vm)
8. [Configure Bot Personas](#step-6-configure-bot-personas)
9. [Verify & Test](#step-7-verify--test)
10. [Day-to-Day Management](#day-to-day-management)
11. [Adding or Replacing a Bot](#adding-or-replacing-a-bot)
12. [Troubleshooting](#troubleshooting)

---

## Quick Start

If you already have 3 Discord bot tokens and your VM is deployed:

```bash
# On the VM — one command does everything
sudo ./automate_discord_setup.sh \
  "BOT_TOKEN_1" "BOT_TOKEN_2" "BOT_TOKEN_3" \
  "SERVER_ID" "CHANNEL_1_ID" "CHANNEL_2_ID" "CHANNEL_3_ID"
```

Otherwise, follow the full guide below.

---

## Prerequisites

| Item | Where to get it |
|------|----------------|
| Discord account | https://discord.com |
| Discord server you own or have admin on | Create one in the Discord app |
| Clawdbot VM already deployed | See [README.md](README.md) — run `deploy_clawdbot_vm.sh` first |
| SSH access to the VM | `ssh root@YOUR_VM_IP` |

---

## Step 1: Create Discord Bot Applications

You need **3 separate bot applications** — one for each Clawdbot instance. Repeat the steps below 3 times.

### 1a. Create the application

1. Go to https://discord.com/developers/applications
2. Click **"New Application"**
3. Name it (suggested names below) and accept the ToS
4. Click **"Create"**

| Instance | Suggested Name | Role |
|----------|---------------|------|
| #1 | `Clawdbot-Research` (or `cornbread`) | Research & analysis |
| #2 | `Clawdbot-Ops` (or `ricebread`) | DevOps & infrastructure |
| #3 | `Clawdbot-Strategy` (or `ubebread`) | Strategy & planning |

### 1b. Get the bot token

1. Go to the **Bot** tab in the left sidebar
2. Click **"Reset Token"** then **"Yes, do it!"**
3. **Copy the token immediately** — it is only shown once
4. Save it somewhere secure (password manager, encrypted notes)

```
Bot 1 token: MTIzNDU2Nzg5MDEy...  (save this!)
Bot 2 token: OTg3NjU0MzIxMDk4...  (save this!)
Bot 3 token: NTY3ODkwMTIzNDU2...  (save this!)
```

### 1c. Enable Privileged Gateway Intents

Still on the **Bot** tab, scroll down to **Privileged Gateway Intents** and toggle **all three** ON:

- [x] **PRESENCE INTENT**
- [x] **SERVER MEMBERS INTENT**
- [x] **MESSAGE CONTENT INTENT** — without this, bots cannot read message text

**Click "Save Changes"** (this is easy to miss and is the #1 cause of "bot is online but doesn't respond").

### 1d. Generate the invite URL

1. Go to the **OAuth2** tab → **URL Generator**
2. Under **Scopes**, check:
   - [x] `bot`
   - [x] `applications.commands`
3. Under **Bot Permissions**, check:
   - [x] View Channels
   - [x] Send Messages
   - [x] Send Messages in Threads
   - [x] Read Message History
   - [x] Embed Links
   - [x] Attach Files
   - [x] Add Reactions
   - [x] Use Slash Commands
4. Copy the generated URL at the bottom — you'll use it in [Step 4](#step-4-invite-bots-to-your-server)

The resulting permission integer should be `277025770560`.

### Checklist

| Bot | Application Name | Token saved? | Intents enabled? | Invite URL copied? |
|-----|-----------------|:------------:|:----------------:|:-----------------:|
| #1  | | [ ] | [ ] | [ ] |
| #2  | | [ ] | [ ] | [ ] |
| #3  | | [ ] | [ ] | [ ] |

---

## Step 2: Set Up Your Discord Server

### Create a server (skip if you already have one)

1. Open Discord (desktop app or browser)
2. Click the **"+"** icon on the left sidebar
3. Choose **"Create My Own"** → **"For me and my friends"**
4. Name it (e.g., `Clawdbot HQ`)

### Create channels

Create text channels for each bot:

| Channel | Bot | Purpose |
|---------|-----|---------|
| `#research` | Clawdbot-Research | Market analysis, web search, data gathering |
| `#ops` | Clawdbot-Ops | Deployments, server management, monitoring |
| `#strategy` | Clawdbot-Strategy | Planning, roadmaps, decision frameworks |
| `#general` | All bots (optional) | Any bot responds when @mentioned |

To create a channel: right-click the server name → **Create Channel** → choose Text → name it → **Create Channel**.

---

## Step 3: Get Server & Channel IDs

### Enable Developer Mode

1. Open Discord **Settings** (gear icon, bottom left)
2. Go to **Advanced** (under App Settings)
3. Toggle **Developer Mode** ON

### Copy IDs

| ID | How to copy |
|----|------------|
| **Server ID** | Right-click the **server name** in the left sidebar → **Copy Server ID** |
| **Channel ID** | Right-click the **channel name** → **Copy Channel ID** |

Save your IDs:

```
SERVER_ID    = _______________

CHANNEL_1_ID = _______________  (#research)
CHANNEL_2_ID = _______________  (#ops)
CHANNEL_3_ID = _______________  (#strategy)
```

---

## Step 4: Invite Bots to Your Server

For **each** bot's invite URL (from [Step 1d](#1d-generate-the-invite-url)):

1. Paste the URL into your browser
2. Select your server from the dropdown
3. Click **"Authorize"**
4. Complete the CAPTCHA if prompted

After authorizing all 3, you should see them in your server's member list (they'll show as offline until the VM services are running):

- Clawdbot-Research (offline)
- Clawdbot-Ops (offline)
- Clawdbot-Strategy (offline)

---

## Step 5: Connect Bots to Clawdbot on the VM

This step links each Discord bot token to its Clawdbot instance on your Hetzner VM. There are two methods.

### Option A: Automated script (recommended)

Upload and run `automate_discord_setup.sh` on your VM:

```bash
# From your Mac — upload the script
scp automate_discord_setup.sh root@YOUR_VM_IP:/root/

# SSH into the VM and run it
ssh root@YOUR_VM_IP

chmod +x /root/automate_discord_setup.sh

./automate_discord_setup.sh \
  "BOT_TOKEN_1" \
  "BOT_TOKEN_2" \
  "BOT_TOKEN_3" \
  "SERVER_ID" \
  "CHANNEL_1_ID" \
  "CHANNEL_2_ID" \
  "CHANNEL_3_ID"
```

The script will:
1. Write each token/channel to the correct instance `.env`
2. Lock down file permissions
3. Restart all 3 services
4. Print status for each instance

### Option B: Manual (clawdbot CLI)

SSH into the VM and run these for each instance:

```bash
ssh root@YOUR_VM_IP
```

**1. Enable the Discord plugin:**

```bash
for i in 1 2 3; do
  HOME=/opt/clawdbot-$i \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-$i/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-$i/.clawdbot/clawdbot.json \
  clawdbot plugins enable discord
done
```

**2. Add the Discord channel with each bot's token:**

```bash
TOKENS=("BOT_TOKEN_1" "BOT_TOKEN_2" "BOT_TOKEN_3")

for i in 0 1 2; do
  INST=$((i+1))
  HOME=/opt/clawdbot-$INST \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-$INST/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-$INST/.clawdbot/clawdbot.json \
  clawdbot channels add --channel discord --token "${TOKENS[$i]}"
done
```

**3. Set group policy to `open`:**

By default Clawdbot uses `groupPolicy: allowlist`, which silently drops all messages. You must change this:

```bash
for i in 1 2 3; do
  HOME=/opt/clawdbot-$i \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-$i/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-$i/.clawdbot/clawdbot.json \
  clawdbot config set channels.discord.groupPolicy open
done
```

**4. Fix permissions and restart (staggered):**

```bash
for i in 1 2 3; do
  chown -R clawdbot:clawdbot /opt/clawdbot-$i
  find /opt/clawdbot-$i -type d -exec chmod 700 {} \;
  find /opt/clawdbot-$i -type f -exec chmod 600 {} \;
done

systemctl start clawdbot@1 && sleep 35
systemctl start clawdbot@2 && sleep 35
systemctl start clawdbot@3 && sleep 35
```

> **Why stagger?** Each instance spikes to ~500MB RAM during startup. Starting all 3 simultaneously on an 8GB VM can cause OOM kills.

---

## Step 6: Configure Bot Personas

Each bot can be given a specialized persona so it responds in character.

### Option A: Set personas via Discord (live)

Just @mention the bot with a `/system` command:

**#research:**
```
@Clawdbot-Research /system You are a senior research analyst. Find information,
analyze markets, summarize reports, and provide data-driven insights. Always cite
sources. Be thorough but concise. Use structured formats (bullets, tables).
```

**#ops:**
```
@Clawdbot-Ops /system You are a senior DevOps/SRE engineer. Help with deployments,
server management, monitoring, and infrastructure. Provide exact copy-paste commands.
Always warn before destructive operations. Include rollback steps.
```

**#strategy:**
```
@Clawdbot-Strategy /system You are a strategic advisor. Create plans, roadmaps,
and decision frameworks. Always present multiple options with tradeoffs. Use frameworks
like RICE/ICE. Think in 3-6-12 month horizons. Format as actionable checklists.
```

### Option B: Load from `clawdbot_roles.json`

The repo includes a `clawdbot_roles.json` file with full persona configs. See that file for detailed system prompts and example commands for each role.

### Example prompts per persona

| Bot | Try these |
|-----|----------|
| Research | `@Research Summarize the latest YC W25 batch — what sectors are trending?` |
| Research | `@Research Compare Hetzner vs DigitalOcean vs Vultr for AI workloads` |
| Ops | `@Ops Check the health of all 3 Clawdbot instances on our Hetzner VM` |
| Ops | `@Ops Write a bash script to back up all /opt/clawdbot-* configs` |
| Strategy | `@Strategy Create a 90-day product roadmap for a Discord bot marketplace` |
| Strategy | `@Strategy Prioritize these features using RICE scoring: [list]` |

---

## Step 7: Verify & Test

### Check services are running

```bash
ssh root@YOUR_VM_IP "for i in 1 2 3; do
  echo \"Instance \$i: \$(systemctl is-active clawdbot@\$i)\"
done"
```

Expected output:
```
Instance 1: active
Instance 2: active
Instance 3: active
```

### Check Discord connection in logs

```bash
ssh root@YOUR_VM_IP 'for i in 1 2 3; do
  echo "=== Instance $i ==="
  journalctl -u clawdbot@$i -n 10 --no-pager -l | grep -i "discord.*logged"
done'
```

Expected:
```
[discord] logged in to discord as 1476529827350843492
```

### Send a test message from the CLI

```bash
ssh root@YOUR_VM_IP 'HOME=/opt/clawdbot-1 \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json \
  clawdbot message send --channel discord --target YOUR_CHANNEL_ID --message "hello from clawdbot"'
```

### Test in Discord

Go to your channel and @mention each bot:

```
@Clawdbot-Research Hello, are you online?
```

The bot should respond within a few seconds.

---

## Day-to-Day Management

### Service commands

```bash
# Check status
ssh root@YOUR_VM_IP "systemctl status clawdbot@1"

# Restart a single bot
ssh root@YOUR_VM_IP "systemctl restart clawdbot@1"

# Stop a bot
ssh root@YOUR_VM_IP "systemctl stop clawdbot@2"

# Restart all (staggered)
ssh root@YOUR_VM_IP "for i in 1 2 3; do systemctl restart clawdbot@\$i; sleep 10; done"
```

### View logs

```bash
# Live tail for one bot
ssh root@YOUR_VM_IP "journalctl -u clawdbot@1 -f"

# Last 100 lines
ssh root@YOUR_VM_IP "journalctl -u clawdbot@1 -n 100 --no-pager"

# All bots interleaved
ssh root@YOUR_VM_IP "journalctl -u 'clawdbot@*' -f"

# Errors only
ssh root@YOUR_VM_IP "journalctl -u clawdbot@1 -p err"
```

### Check Discord channel status

```bash
ssh root@YOUR_VM_IP 'HOME=/opt/clawdbot-1 \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json \
  clawdbot channels status'
```

### Check memory usage

```bash
ssh root@YOUR_VM_IP 'for i in 1 2 3; do
  MEM=$(($(systemctl show clawdbot@$i -p MemoryCurrent --value) / 1048576))
  echo "Instance $i: ${MEM}MB"
done'
```

### Access the web dashboard (optional)

Discord bots do **not** need SSH tunnels — they connect outbound. Tunnels are only for the web UI:

```bash
# From your Mac
ssh -L 8081:127.0.0.1:18789 \
    -L 8082:127.0.0.1:18790 \
    -L 8083:127.0.0.1:18795 \
    root@YOUR_VM_IP
```

Then open:
- Instance 1: http://localhost:8081
- Instance 2: http://localhost:8082
- Instance 3: http://localhost:8083

### Update Clawdbot

```bash
ssh root@YOUR_VM_IP "npm install -g clawdbot@latest && for i in 1 2 3; do systemctl restart clawdbot@\$i; sleep 10; done"
```

---

## Adding or Replacing a Bot

### Add a 4th bot

1. Create a new Discord application ([Step 1](#step-1-create-discord-bot-applications))
2. Invite it to your server ([Step 4](#step-4-invite-bots-to-your-server))
3. On the VM:

```bash
ssh root@YOUR_VM_IP '
  INST=4; PORT=18800
  mkdir -p /opt/clawdbot-$INST
  cp /opt/clawdbot-1/.env /opt/clawdbot-$INST/.env
  sed -i "s/CLAWDBOT_PORT=.*/CLAWDBOT_PORT=$PORT/" /opt/clawdbot-$INST/.env

  # Onboard
  HOME=/opt/clawdbot-$INST \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-$INST/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-$INST/.clawdbot/clawdbot.json \
  clawdbot onboard --non-interactive --accept-risk --mode local \
    --workspace /opt/clawdbot-$INST/workspace \
    --anthropic-api-key "YOUR_API_KEY" \
    --gateway-port $PORT --gateway-bind loopback \
    --gateway-auth off --skip-channels --skip-skills \
    --skip-health --skip-ui --skip-daemon

  # Enable Discord + add token
  HOME=/opt/clawdbot-$INST \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-$INST/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-$INST/.clawdbot/clawdbot.json \
  clawdbot plugins enable discord

  HOME=/opt/clawdbot-$INST \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-$INST/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-$INST/.clawdbot/clawdbot.json \
  clawdbot channels add --channel discord --token "NEW_BOT_TOKEN"

  HOME=/opt/clawdbot-$INST \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-$INST/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-$INST/.clawdbot/clawdbot.json \
  clawdbot config set channels.discord.groupPolicy open

  chown -R clawdbot:clawdbot /opt/clawdbot-$INST
  systemctl enable --now clawdbot@$INST
'
```

> **Port spacing:** Keep gateway ports 5+ apart to avoid derived port collisions. E.g., 18789, 18790, 18795, 18800.

### Replace a bot token

If a token is compromised or you need to regenerate:

1. Go to Discord Developer Portal → your app → Bot → **Reset Token**
2. Copy the new token
3. Update on the VM:

```bash
ssh root@YOUR_VM_IP '
  HOME=/opt/clawdbot-1 \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json \
  clawdbot channels add --channel discord --token "NEW_TOKEN" --force

  chown -R clawdbot:clawdbot /opt/clawdbot-1
  systemctl restart clawdbot@1'
```

---

## Troubleshooting

### Common issues

| Problem | Cause | Fix |
|---------|-------|-----|
| Bot appears offline | Service not running or bad token | Check `systemctl status clawdbot@1`. Verify token in `.env` matches the Developer Portal. |
| Bot is online but ignores messages | `groupPolicy` is `allowlist` (default) | Set to `open`: `clawdbot config set channels.discord.groupPolicy open`. See [Step 5](#option-b-manual-clawdbot-cli). |
| Bot is online but no log entries for messages | MESSAGE CONTENT INTENT not enabled | Developer Portal → Bot → toggle MESSAGE CONTENT INTENT ON → **Save Changes**. Restart service. |
| `"Used disallowed intents"` in logs | Privileged intents not toggled on | Developer Portal → Bot → enable all 3 intents → Save. |
| `"Invalid token"` in logs | Token regenerated or copied wrong | Reset token in Developer Portal → update `.env` → restart. |
| `"Unknown channel: discord"` | Discord plugin not enabled | Run `clawdbot plugins enable discord` for that instance. |
| Bot can't send messages in a channel | Missing permissions | Server Settings → Roles → bot's role → grant Send Messages. Or re-invite with the correct permissions URL. |
| Multiple bots respond to same message | All bots in same channel with open policy | Use `DISCORD_ALLOWED_CHANNELS` in `.env` to limit each bot to its own channel. |
| `EACCES: permission denied` | Ran CLI commands as root, changed file ownership | Fix: `chown -R clawdbot:clawdbot /opt/clawdbot-N` then restart. |
| Service crashes / OOM | Not enough RAM or MemoryMax too low | Upgrade to CAX21 (8GB). Set `MemoryMax=2G` in the systemd service. |
| Port collision error | Derived ports overlap between instances | Space gateway ports 5+ apart (e.g., 18789, 18790, 18795). |
| Service shows `activating` for a long time | Normal — startup takes 20-30 seconds | Wait 35 seconds. Don't start all instances at once. |

### Diagnostic commands

```bash
# Is the service alive?
ssh root@YOUR_VM_IP "systemctl is-active clawdbot@1"

# Last 50 log lines
ssh root@YOUR_VM_IP "journalctl -u clawdbot@1 -n 50 --no-pager"

# Check Discord plugin is enabled
ssh root@YOUR_VM_IP 'HOME=/opt/clawdbot-1 \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json \
  clawdbot plugins list'

# Check channel status
ssh root@YOUR_VM_IP 'HOME=/opt/clawdbot-1 \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json \
  clawdbot channels status'

# Full health check
ssh root@YOUR_VM_IP 'HOME=/opt/clawdbot-1 \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json \
  clawdbot doctor'

# Memory usage per instance
ssh root@YOUR_VM_IP 'for i in 1 2 3; do
  echo "Instance $i: $(($(systemctl show clawdbot@$i -p MemoryCurrent --value) / 1048576))MB"
done'

# Fix permissions (run after any CLI commands as root)
ssh root@YOUR_VM_IP "for i in 1 2 3; do chown -R clawdbot:clawdbot /opt/clawdbot-\$i; done"

# Restart all bots
ssh root@YOUR_VM_IP "for i in 1 2 3; do systemctl restart clawdbot@\$i; sleep 10; done"
```

---

## Architecture Reference

```
┌──────────────────────────────────────────────────────────┐
│  Hetzner VM (Ubuntu 24.04 ARM)  ·  CAX21                │
│  4 vCPU · 8GB RAM · 80GB SSD                            │
│                                                          │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐     │
│  │ clawdbot@1   │ │ clawdbot@2   │ │ clawdbot@3   │     │
│  │ :18789       │ │ :18790       │ │ :18795       │     │
│  │ Research     │ │ Ops          │ │ Strategy     │     │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘     │
│         │                │                │              │
│         └──── Discord WebSocket (outbound only) ┘        │
│                                                          │
│  UFW Firewall: DENY all inbound except SSH (22)          │
└──────────────────────────────────────────────────────────┘
```

- Bots connect **outbound** to Discord via WebSocket — no inbound ports needed
- Each instance has its own `.env`, `.clawdbot/` state dir, and systemd service
- Services run as the `clawdbot` user (non-root, no login shell)
- All gateway ports bound to `127.0.0.1` only
