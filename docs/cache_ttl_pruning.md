# Cache-TTL Context Pruning

Reduces context bloat and Anthropic caching costs by pruning old tool outputs after idle periods.

---

## What It Does

After the TTL expires (e.g. 15 min of inactivity), the next message triggers pruning of **old tool results** from the context window.

**What gets pruned:**
- exec command outputs
- file read results
- web fetch results
- any large tool outputs

**What stays intact:**
- user messages
- assistant messages
- recent tool results (last 3 assistant turns protected)

## Why Use It

1. **Prevents context overflow** — long sessions accumulate tool outputs that fill the context window
2. **Reduces costs** — smaller context = less cacheWrite on first request after idle
3. **Keeps things snappy** — no need to manually clear sessions

## What It Doesn't Do

- Doesn't "reset" or "reboot" the agent
- Doesn't clear conversation history
- Doesn't affect session transcripts on disk
- Doesn't make the agent "forget" what you talked about

The real memory continuity comes from workspace files (SOUL.md, MEMORY.md, memory/*.md), not this setting.

---

## Configuration

Add to `clawdbot.json`:

```json
{
  "agents": {
    "defaults": {
      "contextPruning": {
        "mode": "cache-ttl",
        "ttl": "15m"
      }
    }
  }
}
```

### Options

| Setting | Default | Description |
|---------|---------|-------------|
| `mode` | `"off"` | `"off"` or `"cache-ttl"` |
| `ttl` | `"5m"` | idle time before pruning triggers |
| `keepLastAssistants` | `3` | protect tool results from last N assistant turns |
| `softTrimRatio` | `0.3` | context % threshold for soft trimming |
| `hardClearRatio` | `0.5` | context % threshold for hard clearing |

### Soft vs Hard Pruning

- **Soft trim**: keeps head + tail of large outputs, inserts `...`
- **Hard clear**: replaces entire output with `[Old tool result content cleared]`

---

## CLI Commands

```bash
# apply config change
clawdbot gateway config.patch '{"agents":{"defaults":{"contextPruning":{"mode":"cache-ttl","ttl":"15m"}}}}'

# or edit clawdbot.json directly and restart
clawdbot gateway restart
```

---

## When to Use

**Good for:**
- long-running sessions with lots of exec/read calls
- cost-conscious setups
- agents that go idle between bursts of activity

**Not needed for:**
- short sessions
- sessions with mostly conversation (no heavy tool use)

---

*added 2026-03-01*
