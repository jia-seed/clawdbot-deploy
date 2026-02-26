# Clawdbot 3-Instance VM Deployment

**We deployed three independent Clawdbot (OpenClaw) AI agent instances on a Hetzner Cloud ARM server running Ubuntu 24.04 for ~€3.79/month, with each instance isolated via systemd, memory-capped at 1GB, and accessible only through SSH tunnels.** The entire process — from zero infrastructure to three running instances — took about 10 minutes using the Hetzner CLI and two bash scripts.

---

## Table of Contents
1. [What We Built](#what-we-built)
2. [Prerequisites](#prerequisites)
3. [Step 1: Local Setup (Mac)](#step-1-local-setup-mac)
4. [Step 2: Create the Hetzner VM](#step-2-create-the-hetzner-vm)
5. [Step 3: Deploy Clawdbot](#step-3-deploy-clawdbot)
6. [Step 4: Set API Keys & Start](#step-4-set-api-keys--start)
7. [Step 5: Access Your Instances](#step-5-access-your-instances)
8. [Architecture Overview](#architecture-overview)
9. [Management Commands](#management-commands)
10. [What Each Script Does](#what-each-script-does)
11. [Security Model](#security-model)
12. [Costs](#costs)

---

## What We Built

```
┌─────────────────────────────────────────────────────┐
│  Hetzner VM (Ubuntu 24.04 ARM)  ·  91.98.29.37     │
│  CAX11: 2 vCPU · 4GB RAM · 40GB SSD                │
│                                                     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │
│  │ clawdbot@1  │ │ clawdbot@2  │ │ clawdbot@3  │   │
│  │ :18789      │ │ :18790      │ │ :18791      │   │
│  │ /opt/       │ │ /opt/       │ │ /opt/       │   │
│  │ clawdbot-1/ │ │ clawdbot-2/ │ │ clawdbot-3/ │   │
│  │ ~77MB RAM   │ │ ~71MB RAM   │ │ ~77MB RAM   │   │
│  └─────────────┘ └─────────────┘ └─────────────┘   │
│         │               │               │           │
│         └───────── 127.0.0.1 only ──────┘           │
│                                                     │
│  UFW Firewall: DENY all inbound except SSH (22)     │
└──────────────────────┬──────────────────────────────┘
                       │ SSH tunnel
                       │
              ┌────────┴────────┐
              │   Your Laptop   │
              │  localhost:8081 │
              │  localhost:8082 │
              │  localhost:8083 │
              └─────────────────┘
```

Three completely isolated Clawdbot processes, each with:
- Its own directory, `.env` config, and port
- A systemd service that auto-starts on boot and auto-restarts on crash
- A 1GB memory ceiling (OOM-killed if exceeded, not leaked)
- Zero public network exposure

---

## Prerequisites

- A Mac (or any machine with a terminal)
- A Hetzner Cloud account (https://console.hetzner.cloud)
- A Hetzner API token (project → Security → API Tokens → Read & Write)
- An Anthropic API key (`sk-ant-...`)

---

## Step 1: Local Setup (Mac)

### Generate an SSH key
We need a key pair so we can SSH into the VM without a password.
```bash
ssh-keygen -t ed25519 -C "clawdbot-vm" -f ~/.ssh/id_ed25519 -N ""
```
This creates:
- `~/.ssh/id_ed25519` — private key (stays on your Mac, never share)
- `~/.ssh/id_ed25519.pub` — public key (uploaded to Hetzner)

### Install the Hetzner CLI
```bash
brew install hcloud
```

### Authenticate with your Hetzner API token
```bash
HCLOUD_TOKEN=YOUR_HETZNER_TOKEN hcloud context create clawdbot --token-from-env
```
This saves the token locally so all future `hcloud` commands are authenticated.

---

## Step 2: Create the Hetzner VM

### Upload your SSH public key to Hetzner
```bash
hcloud ssh-key create --name clawdbot-vm --public-key-from-file ~/.ssh/id_ed25519.pub
```

### Create the server
```bash
hcloud server create \
  --name clawdbot-vm \
  --type cax11 \
  --image ubuntu-24.04 \
  --ssh-key clawdbot-vm \
  --location nbg1
```

Output:
```
Server 122180814 created
IPv4: 91.98.29.37
```

**What this creates:**
| Spec | Value |
|------|-------|
| Type | CAX11 (ARM64) |
| CPU | 2 shared vCPU (Ampere Altra) |
| RAM | 4 GB |
| Disk | 40 GB local SSD |
| OS | Ubuntu 24.04 LTS |
| Location | nbg1 (Nuremberg, Germany) |
| Cost | ~€3.79/month |

### Verify SSH access
```bash
ssh -o StrictHostKeyChecking=accept-new root@91.98.29.37 "echo 'SSH OK'"
```
(May need to wait ~15 seconds after creation for the VM to finish booting.)

---

## Step 3: Deploy Clawdbot

### Upload the deploy scripts
```bash
scp deploy_clawdbot_vm.sh multi_clawdbot_config.sh root@91.98.29.37:/root/
```

### Run the main deploy script
```bash
ssh root@91.98.29.37 "chmod +x /root/deploy_clawdbot_vm.sh /root/multi_clawdbot_config.sh && bash /root/deploy_clawdbot_vm.sh"
```

This single command does **everything** on the VM:

```
[1/8] Updating system packages...           ✓ apt update + upgrade
[2/8] Installing Node.js 20.x...            ✓ v20.20.0 via NodeSource
[3/8] Installing utilities (ufw, jq)...     ✓ firewall + JSON tool
[4/8] Creating system user 'clawdbot'...    ✓ non-root service account
[5/8] Installing clawdbot globally...        ✓ npm install -g clawdbot@latest
[6/8] Setting up 3 instance directories...  ✓ /opt/clawdbot-{1,2,3} with .env files
[7/8] Creating systemd service template...  ✓ clawdbot@{1,2,3}.service enabled
[8/8] Configuring firewall (ufw)...         ✓ deny all inbound except SSH
```

---

## Step 4: Set API Keys & Start

### Set the same API key on all 3 instances
```bash
ssh root@91.98.29.37 "for i in 1 2 3; do \
  sed -i \"s|sk-ant-REPLACE_ME_INSTANCE_\${i}|sk-ant-api03-YOUR_ACTUAL_KEY_HERE|\" \
  /opt/clawdbot-\${i}/.env; \
done"
```

### Start all 3 instances
```bash
ssh root@91.98.29.37 "for i in 1 2 3; do systemctl start clawdbot@\${i}; done"
```

### Verify they're running
```bash
ssh root@91.98.29.37 "systemctl status clawdbot@1 clawdbot@2 clawdbot@3 --no-pager -l"
```

Expected output for each:
```
● clawdbot@1.service - Clawdbot Instance 1
     Active: active (running)
     Memory: 76.6M (high: 768.0M max: 1.0G)
```

---

## Step 5: Access Your Instances

Clawdbot binds to `127.0.0.1` only — it is **not** reachable from the public internet. You access it through an SSH tunnel.

### Open tunnels to all 3 instances (one command)
```bash
ssh -L 8081:127.0.0.1:18789 \
    -L 8082:127.0.0.1:18790 \
    -L 8083:127.0.0.1:18791 \
    root@91.98.29.37
```

### Then open in your browser
| Instance | Local URL |
|----------|-----------|
| #1 | http://localhost:8081 |
| #2 | http://localhost:8082 |
| #3 | http://localhost:8083 |

### Background tunnel (stays open without a terminal)
```bash
ssh -f -N \
    -L 8081:127.0.0.1:18789 \
    -L 8082:127.0.0.1:18790 \
    -L 8083:127.0.0.1:18791 \
    root@91.98.29.37
```

---

## Architecture Overview

### File layout on the VM

```
/opt/
├── clawdbot-1/                  # Instance 1 (port 18789)
│   └── .env                     # API key + config (mode 600)
├── clawdbot-2/                  # Instance 2 (port 18790)
│   └── .env
└── clawdbot-3/                  # Instance 3 (port 18791)
    └── .env

/etc/systemd/system/
└── clawdbot@.service            # Template unit (one file, N instances)

/etc/sudoers.d/
└── clawdbot                     # Limited sudo for service restarts

/home/clawdbot/                  # Service account home dir
```

### Process model
- **User:** `clawdbot` (system account, no login shell, no SSH access)
- **Process:** `clawdbot start --port PORT --host 127.0.0.1`
- **Supervisor:** systemd (auto-restart on crash, 5s backoff, max 5 attempts per minute)
- **Memory limit:** 1GB hard cap per instance (`MemoryMax=1G`)
- **Logging:** journald (no separate log files to rotate)

---

## Management Commands

### Service control
```bash
# Status
ssh root@91.98.29.37 "systemctl status clawdbot@1"

# Restart one instance
ssh root@91.98.29.37 "systemctl restart clawdbot@1"

# Stop one instance
ssh root@91.98.29.37 "systemctl stop clawdbot@2"

# Restart all
ssh root@91.98.29.37 "for i in 1 2 3; do systemctl restart clawdbot@\$i; done"
```

### Logs
```bash
# Live tail for instance 1
ssh root@91.98.29.37 "journalctl -u clawdbot@1 -f"

# Last 100 lines
ssh root@91.98.29.37 "journalctl -u clawdbot@1 -n 100 --no-pager"

# All instances interleaved
ssh root@91.98.29.37 "journalctl -u 'clawdbot@*' -f"

# Errors only
ssh root@91.98.29.37 "journalctl -u clawdbot@1 -p err"
```

### Health checks
```bash
# Are ports listening?
ssh root@91.98.29.37 "ss -tlnp | grep '1878[9]\|1879[0-1]'"

# Memory per instance
ssh root@91.98.29.37 "for i in 1 2 3; do echo \"Instance \$i: \$(systemctl show clawdbot@\$i -p MemoryCurrent --value)\"; done"
```

### Update clawdbot
```bash
ssh root@91.98.29.37 "npm install -g clawdbot@latest && for i in 1 2 3; do systemctl restart clawdbot@\$i; sleep 3; done"
```

### Config helper (on the VM)
```bash
sudo /root/multi_clawdbot_config.sh 1 status    # full status report
sudo /root/multi_clawdbot_config.sh 2 setkey     # change API key interactively
sudo /root/multi_clawdbot_config.sh 3 env         # edit .env in nano
sudo /root/multi_clawdbot_config.sh 1 logs        # live log tail
sudo /root/multi_clawdbot_config.sh 2 onboard     # run onboard wizard
```

### Add a 4th instance
```bash
ssh root@91.98.29.37 "
  mkdir -p /opt/clawdbot-4
  cp /opt/clawdbot-1/.env /opt/clawdbot-4/.env
  sed -i 's/CLAWDBOT_PORT=18789/CLAWDBOT_PORT=18792/' /opt/clawdbot-4/.env
  chown -R clawdbot:clawdbot /opt/clawdbot-4
  chmod 700 /opt/clawdbot-4 && chmod 600 /opt/clawdbot-4/.env
  systemctl enable --now clawdbot@4
"
```

### Destroy everything
```bash
# Delete the VM entirely (stops billing)
hcloud server delete clawdbot-vm

# Or just stop instances but keep the VM
ssh root@91.98.29.37 "for i in 1 2 3; do systemctl stop clawdbot@\$i; done"
```

---

## What Each Script Does

### `deploy_clawdbot_vm.sh` — Full automated setup

| Step | What | Why |
|------|------|-----|
| System update | `apt update && apt upgrade` | Patch security vulnerabilities on fresh image |
| Node.js 20 | NodeSource repo → `apt install nodejs` | Clawdbot requires Node.js runtime |
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
- `onboard` — runs `clawdbot onboard --install-daemon` as the clawdbot user in the correct directory
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
| **Binding** | Clawdbot listens on `127.0.0.1` only — unreachable from outside |
| **Access** | SSH tunnel required to reach any instance |
| **User** | Services run as `clawdbot` (no login shell, no SSH) |
| **Privileges** | `NoNewPrivileges=true` in systemd — process cannot escalate |
| **Filesystem** | `ProtectSystem=strict`, `ProtectHome=true`, `PrivateTmp=true` |
| **Secrets** | `.env` files mode `600`, owned by `clawdbot:clawdbot` |
| **Resources** | `MemoryMax=1G` per instance — prevents runaway memory |
| **Recovery** | `Restart=always` with rate limiting (5 attempts per 60 seconds) |

---

## Costs

| Item | Cost |
|------|------|
| Hetzner CAX11 (2 vCPU, 4GB, 40GB SSD) | **€3.79/month** (~$4.10) |
| Anthropic API usage | Per-token (varies by usage) |
| Total infrastructure | **~$4/month** |

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

# 5. Create VM
hcloud server create --name clawdbot-vm --type cax11 --image ubuntu-24.04 --ssh-key clawdbot-vm --location nbg1

# 6. Upload scripts
scp deploy_clawdbot_vm.sh multi_clawdbot_config.sh root@91.98.29.37:/root/

# 7. Run deploy
ssh root@91.98.29.37 "chmod +x /root/*.sh && bash /root/deploy_clawdbot_vm.sh"

# 8. Set API keys
ssh root@91.98.29.37 "for i in 1 2 3; do sed -i \"s|sk-ant-REPLACE_ME_INSTANCE_\${i}|sk-ant-YOUR_KEY|\" /opt/clawdbot-\${i}/.env; done"

# 9. Start all instances
ssh root@91.98.29.37 "for i in 1 2 3; do systemctl start clawdbot@\${i}; done"

# 10. Verify
ssh root@91.98.29.37 "systemctl status clawdbot@1 clawdbot@2 clawdbot@3"

# 11. Access (from your Mac)
ssh -L 8081:127.0.0.1:18789 -L 8082:127.0.0.1:18790 -L 8083:127.0.0.1:18791 root@91.98.29.37
# Then open http://localhost:8081, :8082, :8083
```
