# Deploy Your Own AI Assistant for $4/Month

*The no-fluff guide to running Claude agents 24/7*

---

## What You'll Build

By the end of this guide, you'll have:
- A Claude-powered AI assistant running 24/7
- Discord integration (chat with it anytime)
- Email monitoring and responses
- Persistent memory across conversations
- Total cost: ~$4-12/month

Time required: 30-60 minutes

---

## Chapter 1: Why Self-Host?

**ChatGPT Plus costs $20/month** and you get:
- No API access
- No automation
- No custom integrations
- Usage caps

**Self-hosted setup costs $4-12/month** and you get:
- 24/7 availability
- Full API access
- Discord/Slack/Telegram bots
- Email automation
- Custom personality
- Persistent memory
- Multiple agents

The math is simple. Let's build it.

---

## Chapter 2: Server Setup

### Option A: Hetzner (Recommended)

Best price-to-performance for EU/US.

1. Go to [hetzner.com/cloud](https://www.hetzner.com/cloud)
2. Create account, add payment method
3. Create new project
4. Add server:
   - **Location:** Ashburn or Falkenstein
   - **Image:** Ubuntu 24.04
   - **Type:** CAX11 (2 vCPU, 4GB RAM) - €3.79/month
   - **SSH Key:** Add your public key

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "your@email.com"
cat ~/.ssh/id_ed25519.pub
# Copy this to Hetzner
```

5. Click Create & Buy Now

### Option B: DigitalOcean

1. Go to [digitalocean.com](https://www.digitalocean.com)
2. Create Droplet:
   - **Image:** Ubuntu 24.04
   - **Plan:** Basic, $6/month (1GB RAM)
   - **Region:** NYC or SFO
   - **Auth:** SSH Key

### First Login

```bash
# Connect to your server
ssh root@YOUR_SERVER_IP

# Update system
apt update && apt upgrade -y

# Install essentials
apt install -y curl git htop
```

---

## Chapter 3: Install Clawdbot

Clawdbot is an open-source AI agent framework. One command install:

```bash
# Install Node.js 22
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs

# Install Clawdbot globally
npm install -g clawdbot

# Verify installation
clawdbot --version
```

### Initialize Your Agent

```bash
# Create workspace
mkdir -p /opt/clawdbot && cd /opt/clawdbot

# Initialize
clawdbot init

# This creates:
# - config.yaml (main config)
# - workspace/ (agent's working directory)
```

### Add Your API Key

Get your Anthropic API key from [console.anthropic.com](https://console.anthropic.com)

```bash
# Edit config
nano config.yaml
```

```yaml
# config.yaml
llm:
  provider: anthropic
  model: claude-sonnet-4-20250514
  apiKey: sk-ant-your-key-here

# Optional: Use cheaper model for simple tasks
# model: claude-3-haiku-20240307
```

### Test It

```bash
clawdbot chat
```

You should see a chat interface. Type something. If Claude responds, you're good.

---

## Chapter 4: Discord Integration

### Create a Discord Bot

1. Go to [discord.com/developers/applications](https://discord.com/developers/applications)
2. Click "New Application"
3. Name it (e.g., "My AI Assistant")
4. Go to **Bot** tab
5. Click "Reset Token" and copy it
6. Enable these Intents:
   - Message Content Intent ✓
   - Server Members Intent ✓
   - Presence Intent ✓

### Invite Bot to Your Server

1. Go to **OAuth2 → URL Generator**
2. Select scopes: `bot`, `applications.commands`
3. Select permissions: `Send Messages`, `Read Message History`, `Add Reactions`
4. Copy the URL and open it
5. Select your server and authorize

### Configure Clawdbot

```bash
nano config.yaml
```

```yaml
llm:
  provider: anthropic
  model: claude-sonnet-4-20250514
  apiKey: sk-ant-your-key-here

channels:
  discord:
    enabled: true
    token: YOUR_BOT_TOKEN_HERE
    
    # Who can talk to the bot
    allowlist:
      users:
        - "YOUR_DISCORD_USER_ID"  # Right-click yourself → Copy User ID
    
    # Optional: Respond in specific channels only
    # allowlist:
    #   channels:
    #     - "CHANNEL_ID"
```

### Start the Bot

```bash
clawdbot gateway start
```

Your bot should come online in Discord. Message it!

---

## Chapter 5: Email Integration

### Gmail Setup

1. Go to [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)
2. Generate an app password for "Mail"
3. Copy the 16-character password

```yaml
# Add to config.yaml
tools:
  email:
    enabled: true
    provider: gmail
    address: your@gmail.com
    password: xxxx-xxxx-xxxx-xxxx  # App password
    
    # Optional: Auto-check inbox
    polling:
      enabled: true
      intervalMinutes: 15
```

### What Your Agent Can Do

- Read unread emails
- Search emails by sender/subject
- Draft and send replies
- Summarize long threads

Example prompts:
- "Check my email for anything urgent"
- "Reply to John's email about the meeting"
- "Summarize all emails from this week"

---

## Chapter 6: Run as a Service

Don't run in terminal. Use systemd so it survives reboots.

```bash
# Create service file
nano /etc/systemd/system/clawdbot.service
```

```ini
[Unit]
Description=Clawdbot AI Assistant
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/clawdbot
ExecStart=/usr/bin/clawdbot gateway start --foreground
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start
systemctl daemon-reload
systemctl enable clawdbot
systemctl start clawdbot

# Check status
systemctl status clawdbot

# View logs
journalctl -u clawdbot -f
```

---

## Chapter 7: Customize Your Agent

### Personality

Create `workspace/SOUL.md`:

```markdown
# Who You Are

You are Alex, a sharp and helpful AI assistant.

## Your Style
- Concise but thorough
- Proactive - anticipate needs
- Casual tone, not corporate
- Use emoji sparingly 

## Your Job
- Help with email and scheduling
- Research and summarize
- Remember context between chats
- Be genuinely useful, not performatively helpful
```

### Memory

Your agent automatically maintains memory in `workspace/MEMORY.md` and `workspace/memory/`. It remembers:
- Past conversations
- Your preferences
- Important dates and facts
- Ongoing projects

### Tools

Enable more tools in config.yaml:

```yaml
tools:
  web:
    enabled: true      # Web search
  browser:
    enabled: true      # Browse websites
  calendar:
    enabled: true      # Google Calendar
    # credentials: path/to/credentials.json
```

---

## Chapter 8: Multiple Agents

Run different agents for different purposes.

```bash
# Create separate workspaces
mkdir -p /opt/agent-work
mkdir -p /opt/agent-personal

# Initialize each
cd /opt/agent-work && clawdbot init
cd /opt/agent-personal && clawdbot init
```

Create separate service files with different ports:

```yaml
# /opt/agent-work/config.yaml
gateway:
  port: 3001

# /opt/agent-personal/config.yaml  
gateway:
  port: 3002
```

Each agent has its own:
- Personality (SOUL.md)
- Memory
- Connected accounts
- Discord bot

---

## Chapter 9: Cost Breakdown

### Server: $4-6/month
- Hetzner CAX11: €3.79 (~$4)
- DigitalOcean: $6

### Claude API: $5-20/month (usage-based)

Typical usage patterns:
| Usage | Monthly Cost |
|-------|-------------|
| Light (few chats/day) | $2-5 |
| Medium (active daily use) | $5-15 |
| Heavy (automation + many chats) | $15-30 |

### Cost Optimization Tips

1. **Use Haiku for simple tasks**
   ```yaml
   llm:
     model: claude-3-haiku-20240307  # 10x cheaper
   ```

2. **Set spending limits** at console.anthropic.com

3. **Batch operations** - ask for multiple things at once

4. **Tune heartbeat frequency** - less polling = less cost

### Total: $4-12/month for most users

Compare to ChatGPT Plus at $20/month with no automation.

---

## Chapter 10: Quick Troubleshooting

### Bot not responding in Discord
```bash
# Check if running
systemctl status clawdbot

# Check logs
journalctl -u clawdbot -n 50

# Verify token in config
grep token config.yaml
```

### API errors
- Check API key is correct
- Check you have credits at console.anthropic.com
- Verify model name spelling

### High API costs
- Switch to claude-3-haiku for simple tasks
- Reduce heartbeat frequency
- Check for runaway loops in logs

### Can't connect to server
```bash
# Check SSH
ssh -v root@YOUR_IP

# Check firewall
ufw status
```

---

## Quick Reference

### Useful Commands

```bash
# Start/stop
clawdbot gateway start
clawdbot gateway stop

# Chat directly
clawdbot chat

# Check status
clawdbot status

# View config
cat config.yaml
```

### File Locations

```
/opt/clawdbot/
├── config.yaml          # Main config
├── workspace/
│   ├── SOUL.md          # Personality
│   ├── MEMORY.md        # Long-term memory
│   ├── memory/          # Daily notes
│   └── ...
```

### Links

- Clawdbot Docs: [docs.clawd.bot](https://docs.clawd.bot)
- GitHub: [github.com/clawdbot/clawdbot](https://github.com/clawdbot/clawdbot)
- Anthropic Console: [console.anthropic.com](https://console.anthropic.com)
- Discord: [discord.com/invite/clawd](https://discord.com/invite/clawd)

---

## You're Done!

You now have a 24/7 AI assistant that:
- Runs on your own server
- Costs $4-12/month
- Connects to Discord, email, and more
- Remembers everything
- Works while you sleep

Questions? Join the Clawdbot Discord.

---

*Guide by Andrew | v1.0 | February 2026*
