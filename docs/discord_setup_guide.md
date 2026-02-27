# Discord Setup Guide — 3 Clawdbot Instances

> **Quick Start (30 seconds):** Create 3 Discord bots at discord.com/developers, copy their tokens, then run `sudo ./automate_discord_setup.sh <token1> <token2> <token3> <server-id> <chan1> <chan2> <chan3>` on your VM. Done.

---

## Table of Contents
1. [Create 3 Discord Bot Applications](#step-1-create-3-discord-bot-applications)
2. [Set Up Your Discord Server](#step-2-set-up-your-discord-server)
3. [Get Server & Channel IDs](#step-3-get-server--channel-ids)
4. [Invite All 3 Bots to Your Server](#step-4-invite-all-3-bots-to-your-server)
5. [Open SSH Tunnels from Mac](#step-5-open-ssh-tunnels-from-mac)
6. [Configure Clawdbot Instances on VM](#step-6-configure-clawdbot-instances-on-vm)
7. [Test Each Bot](#step-7-test-each-bot)
8. [Assign Roles & Personas](#step-8-assign-roles--personas)
9. [Troubleshooting](#troubleshooting)

---

## Step 1: Create 3 Discord Bot Applications

You need to create **3 separate bot applications** — one per Clawdbot instance. Repeat these steps 3 times.

### For each bot (repeat 3x):

**1. Go to the Discord Developer Portal**
```
https://discord.com/developers/applications
```

**2. Click "New Application"**
- Name them clearly:
  - Bot 1: `Clawdbot-Research`
  - Bot 2: `Clawdbot-Ops`
  - Bot 3: `Clawdbot-Strategy`
- Accept the Terms of Service
- Click "Create"

**3. Go to the "Bot" tab (left sidebar)**
- Click "Reset Token"
- Click "Yes, do it!"
- **COPY THE TOKEN IMMEDIATELY** — you cannot see it again
- Save each token somewhere safe (password manager, notes app)

```
Bot 1 token: MTIzNDU2Nzg5MDEy...  (save this)
Bot 2 token: OTg3NjU0MzIxMDk4...  (save this)
Bot 3 token: NTY3ODkwMTIzNDU2...  (save this)
```

**4. Enable Privileged Gateway Intents (same page, scroll down)**
Toggle ON all three:
- [x] PRESENCE INTENT
- [x] SERVER MEMBERS INTENT
- [x] MESSAGE CONTENT INTENT ← **critical, bots can't read messages without this**

Click "Save Changes"

**5. Go to "OAuth2" tab → "URL Generator"**
- Under SCOPES, check:
  - [x] `bot`
  - [x] `applications.commands`
- Under BOT PERMISSIONS, check:
  - [x] Send Messages
  - [x] Send Messages in Threads
  - [x] Read Message History
  - [x] Embed Links
  - [x] Attach Files
  - [x] View Channels
  - [x] Add Reactions
  - [x] Use Slash Commands

The permission integer should be: `277025770560`

**6. Copy the generated URL** at the bottom of the page — you'll use it in Step 4.

### Token checklist after creating all 3:

| Bot | Application Name | Token saved? |
|-----|-----------------|--------------|
| #1  | Clawdbot-Research | [ ] |
| #2  | Clawdbot-Ops | [ ] |
| #3  | Clawdbot-Strategy | [ ] |

---

## Step 2: Set Up Your Discord Server

If you don't already have a server:
1. Open Discord (app or browser)
2. Click the "+" icon on the left sidebar
3. Choose "Create My Own" → "For me and my friends"
4. Name it (e.g., "Clawdbot HQ")

### Create 3 channels (one per bot):
1. Right-click the server name → "Create Channel"
2. Create text channels:
   - `#research` — for Clawdbot-Research
   - `#ops` — for Clawdbot-Ops
   - `#strategy` — for Clawdbot-Strategy
3. Optionally create a `#general` channel where all bots can respond

---

## Step 3: Get Server & Channel IDs

### Enable Developer Mode in Discord:
1. Open Discord Settings (gear icon, bottom left)
2. Go to "Advanced" (under App Settings)
3. Toggle ON "Developer Mode"

### Copy the Server ID:
1. Right-click your server name in the left sidebar
2. Click "Copy Server ID"
3. Save it: `SERVER_ID = _______________`

### Copy each Channel ID:
1. Right-click the `#research` channel → "Copy Channel ID"
2. Right-click the `#ops` channel → "Copy Channel ID"
3. Right-click the `#strategy` channel → "Copy Channel ID"

Save them:
```
CHANNEL_1_ID (research)  = _______________
CHANNEL_2_ID (ops)       = _______________
CHANNEL_3_ID (strategy)  = _______________
```

---

## Step 4: Invite All 3 Bots to Your Server

For each bot's OAuth2 URL (from Step 1.6):

1. Paste the URL into your browser
2. Select your server from the dropdown
3. Click "Authorize"
4. Complete the CAPTCHA

After all 3, you should see them appear (offline) in your server's member list:
- Clawdbot-Research (offline)
- Clawdbot-Ops (offline)
- Clawdbot-Strategy (offline)

They'll come online after Step 6.

---

## Step 5: Open SSH Tunnels from Mac

### Quick method (one command):
```bash
ssh -L 8081:127.0.0.1:18789 \
    -L 8082:127.0.0.1:18790 \
    -L 8083:127.0.0.1:18791 \
    root@91.98.29.37
```

### Or use the tunnel manager script:
```bash
chmod +x mac_tunnel_manager.sh
./mac_tunnel_manager.sh up
```

Note: **Discord integration does NOT require SSH tunnels.** The bots connect outbound from the VM to Discord's servers via WebSocket. Tunnels are only needed if you want to access the Clawdbot web UI from your Mac.

---

## Step 6: Configure Clawdbot Instances on VM

### Option A: Automated (recommended)
```bash
ssh root@91.98.29.37

# Upload the script first (from Mac):
# scp automate_discord_setup.sh root@91.98.29.37:/root/

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

### Option B: Manual (per instance)
```bash
# Instance 1
sudo nano /opt/clawdbot-1/.env
```
Add/update these lines:
```env
DISCORD_TOKEN=MTIzNDU2Nzg5MDEy...YOUR_BOT_1_TOKEN
DISCORD_SERVER_ID=1234567890123456789
DISCORD_CHANNEL_ID=1111111111111111111
DISCORD_ALLOWED_CHANNELS=1111111111111111111
```

```bash
sudo chown clawdbot:clawdbot /opt/clawdbot-1/.env
sudo chmod 600 /opt/clawdbot-1/.env
sudo systemctl restart clawdbot@1
```

Repeat for instances 2 and 3 with their respective tokens and channel IDs.

---

## Step 7: Test Each Bot

In Discord, go to each channel and mention the bot:

### #research channel:
```
@Clawdbot-Research Hello, are you online?
```

### #ops channel:
```
@Clawdbot-Ops What's your status?
```

### #strategy channel:
```
@Clawdbot-Strategy Give me a one-sentence test response.
```

### Verify on the VM:
```bash
# Check all services are running
ssh root@91.98.29.37 "systemctl status clawdbot@{1,2,3} --no-pager"

# Watch live logs for instance 1
ssh root@91.98.29.37 "journalctl -u clawdbot@1 -f"
```

You should see Discord connection logs like:
```
[INFO] Discord: Logged in as Clawdbot-Research#1234
[INFO] Discord: Connected to guild "Clawdbot HQ"
[INFO] Discord: Listening in #research
```

---

## Step 8: Assign Roles & Personas

Load the persona configs from `clawdbot_roles.json` — see that file for per-instance system prompts and example commands.

### Quick persona assignment via Discord:

**In #research:**
```
@Clawdbot-Research /system You are a research analyst. Your job is to find information, analyze markets, summarize articles, and provide data-driven insights. Always cite sources. Be thorough but concise.
```

**In #ops:**
```
@Clawdbot-Ops /system You are a DevOps engineer. Your job is to help with deployments, server management, monitoring, CI/CD, and infrastructure. Be precise with commands. Always warn before destructive actions.
```

**In #strategy:**
```
@Clawdbot-Strategy /system You are a strategic advisor. Your job is to create plans, roadmaps, decision frameworks, and competitive analyses. Think long-term. Present options with tradeoffs.
```

---

## Troubleshooting

| Problem | Diagnosis | Fix |
|---------|-----------|-----|
| Bot appears offline in Discord | Service not running or token wrong | `ssh root@VM "systemctl status clawdbot@1"` — check logs for auth errors. Verify token in `.env` matches Discord developer portal. |
| Bot is online but doesn't respond | MESSAGE_CONTENT intent not enabled | Go to Discord Developer Portal → Bot tab → enable MESSAGE CONTENT INTENT → save. Restart service. |
| Bot responds in wrong channel | Channel ID misconfigured | Check `DISCORD_CHANNEL_ID` and `DISCORD_ALLOWED_CHANNELS` in `.env`. Restart service after fixing. |
| "Used disallowed intents" error in logs | Privileged intents not toggled on | Developer Portal → Bot → toggle all 3 intents ON → save. Restart service. |
| Bot can't send messages | Missing permissions in server | Server Settings → Roles → find the bot's role → grant Send Messages. Or re-invite with correct permissions URL. |
| "Invalid token" in logs | Token was regenerated or copied wrong | Go to Developer Portal → Bot → Reset Token → copy new one → update `.env` → restart. |
| Service crashes immediately | Missing DISCORD_TOKEN in .env | `ssh root@VM "grep DISCORD_TOKEN /opt/clawdbot-1/.env"` — make sure it's set and not commented out. |
| Rate limited by Discord | Too many messages too fast | Normal — Discord rate limits bots. Clawdbot handles this automatically. Wait a few seconds. |
| Can't reach web UI via tunnel | SSH tunnel not open | Run `./mac_tunnel_manager.sh up` or the manual SSH command from Step 5. |
| Multiple bots respond to same message | Bots in same channel with no allowlist | Set `DISCORD_ALLOWED_CHANNELS` to limit each bot to its own channel. |

### Quick diagnostic commands:
```bash
# Is the service alive?
ssh root@91.98.29.37 "systemctl is-active clawdbot@1"

# Last 50 log lines
ssh root@91.98.29.37 "journalctl -u clawdbot@1 -n 50 --no-pager"

# Is Discord token set?
ssh root@91.98.29.37 "grep -c DISCORD_TOKEN /opt/clawdbot-1/.env"

# Memory usage
ssh root@91.98.29.37 "systemctl show clawdbot@1 -p MemoryCurrent --value"

# Restart all bots
ssh root@91.98.29.37 "for i in 1 2 3; do systemctl restart clawdbot@\$i; done"
```
