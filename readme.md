# jiawdbots

[![clawdbot](https://img.shields.io/badge/powered%20by-clawdbot-blue)](https://github.com/clawdbot/clawdbot)
[![hetzner](https://img.shields.io/badge/hosted%20on-hetzner-red)](https://www.hetzner.com/cloud)
[![deepseek](https://img.shields.io/badge/model-deepseek--chat-purple)](https://openrouter.ai/deepseek/deepseek-chat)
[![license](https://img.shields.io/badge/license-MIT-green)](license)

3 clawdbot instances on a hetzner vm (~$4/month), connected to discord

## model

runs **deepseek-chat** via [openrouter](https://openrouter.ai) (`openrouter/deepseek/deepseek-chat`)

set `OPENROUTER_API_KEY` in each instance `.env` and configure the primary model in `.clawdbot/clawdbot.json`:

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/deepseek/deepseek-chat"
      }
    }
  }
}
```

## docs

- [discord + github setup](docs/claude_code_discord_setup.md)
- [discord bot setup](docs/discord_bot_setup.md)
- [shared memory](docs/shared_memory.md)
- [google workspace](docs/google_workspace_setup.md)
- [mac node setup](docs/mac_node_setup.md)
- [custom check-ins](docs/custom_checkins.md)
- [cache-ttl pruning](docs/cache_ttl_pruning.md) - reduce context bloat + costs

## scripts

- `deploy_clawdbot_vm.sh` - main vm deployment
- `setup_shared_memory.sh` - multi-bot memory
- `automate_discord_setup.sh` - discord automation

## workspace files

- [agents.md](agents.md) - workspace behavior
- [soul.md](soul.md) - personality
- [identity.md](identity.md) - bot identity template
- [bootstrap.md](bootstrap.md) - first run
- [tools.md](tools.md) - local tool notes
