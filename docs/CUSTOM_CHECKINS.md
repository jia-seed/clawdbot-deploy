# Custom Check-ins

A randomized check-in system that messages users naturally instead of at fixed intervals.

## How It Works

- **Runs hourly** from 9am to 1am PST (no messages during sleep hours)
- **Randomized timing**: 
  - 30% chance to send after 2-4 hours since last check-in
  - 60% chance after 4-5 hours
  - 100% chance after 5+ hours
- **Smart throttling**: Won't message again if the user hasn't responded to the last check-in
- **State tracking**: Persists in `workspace/memory/checkin-state.json`

## Setup

After your Clawdbot instance is running:

```bash
# Upload the script
scp setup_custom_checkins.sh root@YOUR_VM_IP:/root/

# Run it for instance 1
ssh root@YOUR_VM_IP "bash /root/setup_custom_checkins.sh 1 YOUR_DISCORD_CHANNEL_ID your_username"
```

### Arguments

| Arg | Description | Example |
|-----|-------------|---------|
| `instance` | Clawdbot instance number | `1` |
| `discord_channel_id` | Discord channel ID to message | `1476798913372749836` |
| `user_name` | Name to use in check-ins (optional) | `jia` |

## State File

The system tracks state in `workspace/memory/checkin-state.json`:

```json
{
  "lastCheckinMs": 1772176743869,
  "lastCheckinResponded": true
}
```

- `lastCheckinMs`: Timestamp of last sent check-in
- `lastCheckinResponded`: Whether the user responded since the last check-in

## Customization

To modify the behavior, edit the cron job via the Clawdbot web UI or CLI:

```bash
# List cron jobs
HOME=/opt/clawdbot-1 \
CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot \
CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json \
clawdbot cron list

# Update a job
clawdbot cron update --id JOB_ID --schedule "0 10-22 * * *"  # Change hours
```

## Disable

```bash
# Disable the cron job
HOME=/opt/clawdbot-1 \
CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot \
CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json \
clawdbot cron update --id JOB_ID --enabled false

# Or delete it
clawdbot cron remove --id JOB_ID
```
