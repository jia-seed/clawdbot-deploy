# Deploy Your Own AI Assistant for $4/Month

## The Complete Guide to Running Claude-Powered Agents on a Cheap VPS

---

# Introduction

What if you could have your own AI assistant that:
- Monitors your email and responds in your voice
- Manages your calendar and schedules meetings
- Runs 24/7 on a server you control
- Costs less than a coffee per month

This isn't hypothetical. I run three AI assistants on a single $4/month server. They handle my email, remind me of tasks, and even send messages on my behalf.

This guide shows you exactly how to do the same.

---

# Chapter 1: Why Self-Host?

**Cost comparison:**
- ChatGPT Plus: $20/month (and you still can't automate anything)
- Claude Pro: $20/month (same problem)
- Self-hosted AI agent: $4/month + API costs (~$5-10/month depending on usage)

**What you get:**
- Full automation (not just chat)
- Runs while you sleep
- Connects to your email, calendar, Discord, Slack
- Customizable personality and rules
- Your data stays on your server

---

# Chapter 2: What You'll Need

1. **A VPS (Virtual Private Server)** - $4-7/month
   - Hetzner Cloud (recommended): €3.79/month for ARM server
   - DigitalOcean: $4/month droplet
   - Vultr: $5/month

2. **An Anthropic API key** - pay per use
   - ~$0.01 per short conversation
   - ~$5-10/month for moderate use

3. **Basic terminal knowledge**
   - SSH into a server
   - Run commands
   - Edit text files

4. **30 minutes of setup time**

---

# Chapter 3: Server Setup

## Step 1: Create your VPS

### Hetzner (Recommended)
1. Go to console.hetzner.cloud
2. Create new project
3. Add server:
   - Location: Falkenstein or Helsinki (cheapest)
   - Image: Ubuntu 24.04
   - Type: CAX11 (ARM, 2 vCPU, 4GB RAM) - €3.79/month
   - SSH key: Add your public key

### DigitalOcean
1. Create Droplet
2. Ubuntu 24.04
3. Basic plan, $4/month
4. Add SSH key

## Step 2: Connect to your server

```bash
ssh root@YOUR_SERVER_IP
```

## Step 3: Initial setup

```bash
# Update system
apt update && apt upgrade -y

# Install Node.js 22
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs

# Create a non-root user
useradd -m -s /bin/bash clawdbot
usermod -aG sudo clawdbot

# Switch to new user
su - clawdbot
```

---

# Chapter 4: Installing Clawdbot

Clawdbot is an open-source AI agent framework that makes this easy.

```bash
# Install globally
sudo npm install -g clawdbot

# Initialize
clawdbot init

# Add your Anthropic API key
clawdbot config set anthropic.apiKey YOUR_API_KEY
```

## Configure your agent

Edit `~/.clawdbot/config.yaml`:

```yaml
agent:
  name: "assistant"
  model: "claude-sonnet-4-20250514"
  
workspace:
  path: "~/workspace"
```

---

# Chapter 5: Connecting to Discord

Your AI assistant needs a way to talk to you. Discord is the easiest.

## Create a Discord bot

1. Go to discord.com/developers/applications
2. New Application → Name it
3. Go to Bot → Reset Token → Copy it
4. Enable these Privileged Intents:
   - Message Content Intent
   - Server Members Intent
5. Go to OAuth2 → URL Generator
   - Scopes: bot, applications.commands
   - Permissions: Send Messages, Read Messages, etc.
6. Copy the URL and open it to invite bot to your server

## Add to Clawdbot

```bash
clawdbot config set discord.token YOUR_BOT_TOKEN
clawdbot config set discord.channels.allowlist CHANNEL_ID
```

---

# Chapter 6: Running as a Service

You want this running 24/7, even after reboots.

```bash
# Create systemd service
sudo nano /etc/systemd/system/clawdbot.service
```

```ini
[Unit]
Description=Clawdbot AI Agent
After=network.target

[Service]
Type=simple
User=clawdbot
WorkingDirectory=/home/clawdbot
ExecStart=/usr/bin/clawdbot gateway run
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start
sudo systemctl enable clawdbot
sudo systemctl start clawdbot

# Check status
sudo systemctl status clawdbot
```

---

# Chapter 7: Adding Email Integration

Connect Gmail so your assistant can read and respond to emails.

## Setup Google OAuth

1. Go to console.cloud.google.com
2. Create project
3. Enable Gmail API
4. Create OAuth credentials
5. Download credentials.json

## Connect to Clawdbot

```bash
# Install Google integration
npm install -g gog-cli

# Authenticate
gog auth login --account your@email.com
```

Now your assistant can:
- Read your inbox
- Send emails in your voice
- Schedule meetings based on your availability

---

# Chapter 8: Customizing Your Assistant

## Personality (SOUL.md)

Create `~/workspace/SOUL.md`:

```markdown
# Who You Are

You're a helpful assistant. Be concise, friendly, and proactive.

## Rules
- Check email every 30 minutes
- Alert me for anything urgent
- Draft replies but ask before sending
```

## Memory

Your assistant remembers things in `~/workspace/memory/`:
- Daily notes
- Long-term memories
- Preferences learned over time

---

# Chapter 9: Running Multiple Assistants

Want separate assistants for different tasks? Run multiple instances.

```bash
# Create directories
mkdir -p /opt/clawdbot-{1,2,3}

# Each gets its own config and workspace
# Instance 1: Research
# Instance 2: Operations  
# Instance 3: Strategy
```

Total cost: Still $4/month for the server, just more API usage.

---

# Chapter 10: Cost Optimization

## Reduce API costs

1. **Use Claude Haiku for simple tasks** - 10x cheaper
2. **Set up caching** - Don't re-process the same things
3. **Batch operations** - Check email every 30 min, not every minute

## My actual costs

- Server: $4/month
- API (3 assistants, moderate use): ~$8/month
- **Total: ~$12/month** for 3 AI assistants running 24/7

---

# Quick Start Checklist

- [ ] Create Hetzner/DigitalOcean account
- [ ] Spin up $4 Ubuntu server
- [ ] SSH in and install Node.js
- [ ] Install Clawdbot
- [ ] Add Anthropic API key
- [ ] Create Discord bot and connect
- [ ] Set up systemd service
- [ ] Customize personality
- [ ] (Optional) Add email integration

---

# Resources

- Clawdbot GitHub: github.com/clawdbot/clawdbot
- Clawdbot Docs: docs.clawd.bot
- Hetzner Cloud: hetzner.com/cloud
- Anthropic API: anthropic.com

---

# About

This guide was written by someone running this exact setup. Three AI assistants, one cheap server, handling email, Discord, and automation daily.

Questions? The Clawdbot Discord community is helpful: discord.com/invite/clawd

---

*Now go build your AI assistant.*
