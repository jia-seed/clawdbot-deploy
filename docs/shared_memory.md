# Shared Memory System

A git-backed shared knowledge base for the 3 Clawdbot Discord bot instances. Memories persist across crashes, restarts, and conversations, and auto-sync to a private GitHub repo every 5 minutes.

---

## How It Works

```
/opt/clawdbot-memory/            ← shared git repo on the VM
├── shared/                      ← all bots read/write
├── bot-1-research/              ← cornbread's notes
├── bot-2-ops/                   ← ricebread's notes
└── bot-3-strategy/              ← ubebread's notes

/opt/clawdbot-{1,2,3}/workspace/memory/  ← symlinks to above
```

- Each bot instance has a symlink at `workspace/memory/` pointing to `/opt/clawdbot-memory/`
- Bots read and write markdown files naturally through their workspace
- A cron job runs every 5 minutes to `git commit && git push` any changes
- The remote repo is **private**: `github.com/jia-seed/clawdbot-memory`

---

## Setup

### Prerequisites

- VM deployed with `deploy_clawdbot_vm.sh` (instances at `/opt/clawdbot-{1,2,3}`)
- Private GitHub repo created: `jia-seed/clawdbot-memory`

### Run the setup script

```bash
# From your Mac — upload both scripts
scp setup_shared_memory.sh sync-memory.sh root@YOUR_VM_IP:/root/

# SSH in and run
ssh root@YOUR_VM_IP "chmod +x /root/setup_shared_memory.sh /root/sync-memory.sh && bash /root/setup_shared_memory.sh"
```

The script will:
1. Create `/opt/clawdbot-memory/` with the full directory structure
2. Generate an SSH deploy key and pause — you add it to GitHub
3. Initialize git, make the first commit, push
4. Create symlinks in each bot's workspace
5. Update systemd `ReadWritePaths` so bots can write to the shared dir
6. Install the sync cron job (every 5 min as `clawdbot` user)
7. Fix permissions and stagger-restart all 3 services

---

## Directory Structure

| Path | Purpose | Who writes |
|------|---------|-----------|
| `shared/project-context.md` | Team info, infrastructure, key context | All bots |
| `shared/team-knowledge.md` | Shared facts and learnings | All bots |
| `shared/decisions.md` | Record of decisions made | All bots |
| `shared/links-and-resources.md` | Useful links and references | All bots |
| `bot-1-research/notes.md` | cornbread's working notes | Bot 1 |
| `bot-1-research/research-log.md` | Research findings log | Bot 1 |
| `bot-1-research/sources.md` | Sources and references | Bot 1 |
| `bot-2-ops/notes.md` | ricebread's working notes | Bot 2 |
| `bot-2-ops/runbooks.md` | Standard operating procedures | Bot 2 |
| `bot-2-ops/incident-log.md` | Incident history | Bot 2 |
| `bot-3-strategy/notes.md` | ubebread's working notes | Bot 3 |
| `bot-3-strategy/roadmap.md` | Product/project roadmap | Bot 3 |
| `bot-3-strategy/decisions-log.md` | Strategy decisions log | Bot 3 |

---

## Usage

### Ask a bot to save a memory

```
@cornbread Save a note in memory/bot-1-research/notes.md — we decided to use Hetzner for all infra
```

```
@ricebread Write to memory/shared/team-knowledge.md that our API rate limit is 1000 req/min
```

### Ask a bot to recall memories

```
@ubebread Read memory/shared/decisions.md and summarize our recent decisions
```

```
@cornbread Check memory/shared/links-and-resources.md for any research sources we've saved
```

### Manually edit on GitHub

You can edit memory files directly on GitHub. Changes sync down to the VM on the next cron run (within 5 minutes).

---

## Management

### Check sync status

```bash
# View sync log
ssh root@YOUR_VM_IP "tail -20 /opt/clawdbot-memory/.sync/sync.log"

# Check cron is installed
ssh root@YOUR_VM_IP "crontab -u clawdbot -l"
```

### Force an immediate sync

```bash
ssh root@YOUR_VM_IP "sudo -u clawdbot /opt/clawdbot-memory/.sync/sync-memory.sh"
```

### Check symlinks

```bash
ssh root@YOUR_VM_IP "for i in 1 2 3; do ls -la /opt/clawdbot-\$i/workspace/memory; done"
```

### View memories on GitHub

Browse to: https://github.com/jia-seed/clawdbot-memory

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Sync not pushing | Check deploy key: `ssh root@VM "sudo -u clawdbot ssh -F /opt/clawdbot-memory/.deploy-key/config -T github-memory 2>&1"` |
| Permission denied on memory files | Fix ownership: `ssh root@VM "chown -R clawdbot:clawdbot /opt/clawdbot-memory"` |
| Bot can't write to memory/ | Check systemd ReadWritePaths includes `/opt/clawdbot-memory`: `grep ReadWritePaths /etc/systemd/system/clawdbot@.service` |
| Cron not running | Verify: `ssh root@VM "crontab -u clawdbot -l"` — should show `*/5 * * * * /opt/clawdbot-memory/.sync/sync-memory.sh` |
| Git merge conflict | SSH in, resolve manually: `cd /opt/clawdbot-memory && git status` |
| Symlink broken | Recreate: `ln -sf /opt/clawdbot-memory /opt/clawdbot-N/workspace/memory` |
