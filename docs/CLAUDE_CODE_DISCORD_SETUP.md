# Discord Bot Setup for Claude Code (Clawdbot)

A complete guide to connecting Claude Code (Clawdbot) to Discord. This covers single-bot setups, multi-bot deployments, GitHub integration, and full configuration.

---

## Table of Contents

1. [Quick Start](#quick-start-5-minutes)
2. [Full Discord Setup](#full-setup-guide)
3. [Claude Code Configuration](#claude-code-configuration)
4. [GitHub Integration](#github-integration)
5. [Configuration Options](#configuration-options)
6. [Troubleshooting](#troubleshooting)
7. [Multi-Bot Setup](#multi-bot-setup-multiple-instances)
8. [Bot Personas](#bot-personas)
9. [Architecture](#architecture)

---

## Quick Start (5 minutes)

Already have a Discord bot token? Run this:

```bash
# enable discord plugin
clawdbot plugins enable discord

# add your bot token
clawdbot channels add --channel discord --token "YOUR_BOT_TOKEN"

# allow messages from all channels (not just allowlisted ones)
clawdbot config set channels.discord.groupPolicy open

# restart to apply
clawdbot gateway restart
```

done. your bot should come online in discord.

---

## Full Setup Guide

### Step 1: Create a Discord Bot

1. go to https://discord.com/developers/applications
2. click "New Application"
3. name it whatever you want (e.g., "corn", "mybot")
4. click "Create"

### Step 2: Get Your Bot Token

1. go to the "Bot" tab in the left sidebar
2. click "Reset Token"
3. click "Yes, do it!"
4. **copy the token immediately** (you can only see it once)
5. save it somewhere safe

### Step 3: Enable Message Content Intent

this is the most common reason bots don't respond. still on the Bot tab:

1. scroll down to "Privileged Gateway Intents"
2. enable all three:
   - [x] PRESENCE INTENT
   - [x] SERVER MEMBERS INTENT
   - [x] MESSAGE CONTENT INTENT (required to read messages)
3. click "Save Changes"

### Step 4: Generate Invite Link

1. go to "OAuth2" tab, then "URL Generator"
2. under SCOPES, check:
   - [x] `bot`
   - [x] `applications.commands`
3. under BOT PERMISSIONS, check:
   - [x] View Channels
   - [x] Send Messages
   - [x] Send Messages in Threads
   - [x] Read Message History
   - [x] Embed Links
   - [x] Attach Files
   - [x] Add Reactions
   - [x] Use Slash Commands
4. copy the generated URL at the bottom

### Step 5: Invite Bot to Your Server

1. paste the URL in your browser
2. select your server
3. click "Authorize"
4. complete the captcha

the bot will appear offline in your server until you connect it to clawdbot.

### Step 6: Connect to Clawdbot

```bash
# enable the discord plugin
clawdbot plugins enable discord

# add your token
clawdbot channels add --channel discord --token "YOUR_BOT_TOKEN_HERE"

# set group policy to open (required to respond in servers)
clawdbot config set channels.discord.groupPolicy open

# restart
clawdbot gateway restart
```

### Step 7: Test It

in discord, mention your bot:

```
@yourbot hello, are you there?
```

it should respond within a few seconds.

---

## Claude Code Configuration

### Initial Setup (Onboarding)

first time setup:

```bash
clawdbot onboard
```

this walks you through:
- selecting an AI provider (anthropic, openai, etc.)
- adding API keys
- setting up your workspace
- configuring the gateway

### API Keys

add your AI provider API key:

```bash
# anthropic (claude)
clawdbot auth add --provider anthropic --api-key "sk-ant-..."

# openai
clawdbot auth add --provider openai --api-key "sk-..."

# or set via environment variable
export ANTHROPIC_API_KEY="sk-ant-..."
```

### Model Selection

set your default model:

```bash
# use claude sonnet
clawdbot config set agents.defaults.model.primary "anthropic/claude-sonnet-4-20250514"

# use claude opus
clawdbot config set agents.defaults.model.primary "anthropic/claude-opus-4-5"

# use gpt-4
clawdbot config set agents.defaults.model.primary "openai/gpt-4o"
```

### Workspace Configuration

your bot's workspace is where it stores files, memories, and configs:

```bash
# default location
~/.clawdbot/agents/main/workspace/

# or set custom workspace
clawdbot config set agents.defaults.workspace "/path/to/your/workspace"
```

key workspace files:
- `SOUL.md` - bot personality and behavior
- `USER.md` - info about you (the human)
- `MEMORY.md` - long-term memories
- `AGENTS.md` - how the bot should operate
- `TOOLS.md` - tool-specific notes

### Config File Location

main config file:
```
~/.clawdbot/clawdbot.json
```

view current config:
```bash
clawdbot config get
```

edit directly:
```bash
nano ~/.clawdbot/clawdbot.json
```

### Example Config

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-sonnet-4-20250514"
      },
      "workspace": "/opt/clawdbot/workspace"
    }
  },
  "channels": {
    "discord": {
      "enabled": true,
      "groupPolicy": "open"
    }
  },
  "gateway": {
    "port": 18789,
    "bind": "loopback"
  }
}
```

---

## GitHub Integration

let your bot push code, create branches, and manage repos.

### Step 1: Generate SSH Key

```bash
# generate a new key pair
ssh-keygen -t ed25519 -C "clawdbot" -f ~/.ssh/id_ed25519 -N ""

# view the public key
cat ~/.ssh/id_ed25519.pub
```

### Step 2: Add Key to GitHub

1. go to https://github.com/settings/keys
2. click "New SSH key"
3. paste your public key
4. click "Add SSH key"

### Step 3: Configure Git

```bash
git config --global user.name "your-bot-name"
git config --global user.email "bot@yourdomain.com"
```

### Step 4: Test Connection

```bash
ssh -T git@github.com
```

should see: "Hi username! You've successfully authenticated..."

### Using GitHub from Your Bot

once configured, your bot can:

```bash
# clone repos
git clone git@github.com:user/repo.git

# create branches
git checkout -b new-feature

# commit and push
git add .
git commit -m "add feature"
git push origin new-feature
```

### GitHub CLI (Optional)

for more advanced github operations:

```bash
# install gh cli
brew install gh  # mac
apt install gh   # ubuntu

# authenticate
gh auth login

# now your bot can create PRs, issues, etc.
gh pr create --title "New feature" --body "Description"
gh issue create --title "Bug report" --body "Details"
```

### SSH Config for Multiple Keys

if you have multiple github accounts:

```bash
# ~/.ssh/config
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519

Host github-work
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_work
```

then clone with: `git clone git@github-work:org/repo.git`

---

## Configuration Options

### Group Policy

controls whether the bot responds in servers:

```bash
# respond in all channels (recommended for personal use)
clawdbot config set channels.discord.groupPolicy open

# only respond in allowlisted guilds/channels
clawdbot config set channels.discord.groupPolicy allowlist

# disable server responses entirely (DMs only)
clawdbot config set channels.discord.groupPolicy disabled
```

### DM Policy

controls who can DM the bot:

```bash
# allow DMs from anyone
clawdbot config set channels.discord.dm.policy open

# only allow DMs from allowlisted users
clawdbot config set channels.discord.dm.policy allowlist

# require pairing first
clawdbot config set channels.discord.dm.policy pairing
```

### Allowlisting Specific Guilds

if using `groupPolicy: allowlist`:

```json
{
  "channels": {
    "discord": {
      "groupPolicy": "allowlist",
      "guilds": {
        "YOUR_SERVER_ID": {
          "channels": {
            "YOUR_CHANNEL_ID": {
              "enabled": true
            }
          }
        }
      }
    }
  }
}
```

---

## Troubleshooting

| problem | cause | fix |
|---------|-------|-----|
| bot is offline | service not running | `clawdbot gateway status` then `clawdbot gateway start` |
| bot is online but ignores messages | MESSAGE CONTENT intent not enabled | discord developer portal, bot tab, enable the intent, save |
| bot is online but ignores server messages | groupPolicy is "allowlist" | `clawdbot config set channels.discord.groupPolicy open` |
| "invalid token" error | token wrong or regenerated | get new token from developer portal, run `clawdbot channels add` again |
| "used disallowed intents" | intents not enabled in portal | enable all 3 intents in developer portal, bot tab |
| bot can't send messages | missing permissions | re-invite with correct permissions or fix role in server settings |

### Check Logs

```bash
# view recent logs
clawdbot logs --lines 50

# live tail
clawdbot logs -f

# check discord-specific logs
clawdbot logs | grep -i discord
```

### Verify Connection

```bash
# check channel status
clawdbot channels status

# check if discord plugin is enabled
clawdbot plugins list | grep discord
```

---

## Multi-Bot Setup (Multiple Instances)

for running multiple bots on the same server, each needs its own clawdbot instance:

### Directory Structure

```
/opt/clawdbot-1/   # bot 1 (research)
/opt/clawdbot-2/   # bot 2 (ops)  
/opt/clawdbot-3/   # bot 3 (strategy)
```

### Environment Variables

each instance needs its own env:

```bash
# instance 1
export HOME=/opt/clawdbot-1
export CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot
export CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json

clawdbot channels add --channel discord --token "BOT_1_TOKEN"
```

### Port Spacing

keep gateway ports 5+ apart to avoid collisions:
- instance 1: 18789
- instance 2: 18794
- instance 3: 18799

### Systemd Services

use the template service:

```bash
systemctl enable clawdbot@1
systemctl enable clawdbot@2
systemctl enable clawdbot@3
```

see `deploy_clawdbot_vm.sh` for the full multi-instance setup.

---

## Bot Personas

give your bot a personality with system prompts:

### Via Discord

```
@yourbot /system you are a chill assistant. keep responses brief, lowercase, no emojis.
```

### Via Config

edit your workspace `SOUL.md` file:

```markdown
# SOUL.md

## Vibe

lowercase. casual. warm but to the point.

- no caps unless really needed
- no emojis
- brief responses
- friendly energy
```

---

## Useful Commands

```bash
# enable discord
clawdbot plugins enable discord

# add/update token
clawdbot channels add --channel discord --token "TOKEN"

# check status
clawdbot channels status

# set group policy
clawdbot config set channels.discord.groupPolicy open

# view config
clawdbot config get channels.discord

# restart gateway
clawdbot gateway restart

# view logs
clawdbot logs -f
```

---

## Architecture

```
┌─────────────────────────────────────────┐
│  Your Server / VM                       │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Clawdbot Gateway               │   │
│  │  - Discord plugin (outbound WS) │   │
│  │  - Claude/OpenAI API calls      │   │
│  │  - Local file access            │   │
│  └──────────────┬──────────────────┘   │
│                 │                       │
└─────────────────┼───────────────────────┘
                  │ outbound websocket
                  ▼
          ┌───────────────┐
          │ Discord API   │
          └───────────────┘
```

- bot connects outbound to discord (no inbound ports needed)
- all traffic is encrypted via discord's websocket
- gateway binds to localhost only by default
