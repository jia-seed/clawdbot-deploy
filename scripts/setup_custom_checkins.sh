#!/bin/bash
# setup_custom_checkins.sh - Set up randomized check-in cron job for a Clawdbot instance
#
# Usage: ./setup_custom_checkins.sh <instance> <discord_channel_id> [user_name]
#
# This creates a custom check-in system that:
# - Runs hourly from 9am to 1am PST
# - Randomly decides whether to send (30% at 2-4h, 60% at 4-5h, 100% at 5h+)
# - Won't message again if user hasn't responded to last check-in
# - Tracks state in memory/checkin-state.json

set -e

INSTANCE="${1:-1}"
CHANNEL_ID="${2}"
USER_NAME="${3:-jia}"

if [ -z "$CHANNEL_ID" ]; then
    echo "Usage: $0 <instance> <discord_channel_id> [user_name]"
    echo "Example: $0 1 1476798913372749836 jia"
    exit 1
fi

INSTANCE_DIR="/opt/clawdbot-$INSTANCE"
WORKSPACE="$INSTANCE_DIR/workspace"
STATE_DIR="$WORKSPACE/memory"
STATE_FILE="$STATE_DIR/checkin-state.json"

echo "Setting up custom check-ins for instance $INSTANCE..."

# Create state directory and initial state file
mkdir -p "$STATE_DIR"
cat > "$STATE_FILE" << 'EOF'
{
  "lastCheckinMs": 0,
  "lastCheckinResponded": true
}
EOF

chown -R clawdbot:clawdbot "$STATE_DIR"

# Create the cron job via clawdbot CLI
CRON_MESSAGE="randomized check-in logic for $USER_NAME:

1. read memory/checkin-state.json to get lastCheckinMs and lastCheckinResponded
2. calculate hours since last check-in
3. use the discord message tool with target channel:$CHANNEL_ID and action read to check if $USER_NAME responded since your last check-in. update lastCheckinResponded accordingly.
4. decide whether to send:
   - if lastCheckinResponded is false: do NOT send, just update state file and reply NO_REPLY
   - if less than 2 hours since last: do NOT send, reply NO_REPLY  
   - if 2-4 hours: 30% chance to send
   - if 4-5 hours: 60% chance to send
   - if 5+ hours: definitely send
5. if sending: either ask how they're doing casually OR share a genuinely interesting fun fact. keep it lowercase, warm, no emojis. then update state file with new timestamp and set lastCheckinResponded to false.
6. if not sending: reply NO_REPLY

create the state file if it doesn't exist (default to 0 for lastCheckinMs, true for lastCheckinResponded)."

# Add cron job using the gateway API
# This requires the gateway to be running
HOME="$INSTANCE_DIR" \
CLAWDBOT_STATE_DIR="$INSTANCE_DIR/.clawdbot" \
CLAWDBOT_CONFIG_PATH="$INSTANCE_DIR/.clawdbot/clawdbot.json" \
clawdbot cron add \
    --name "check-in-$USER_NAME" \
    --schedule "0 9-23,0,1 * * *" \
    --tz "America/Los_Angeles" \
    --message "$CRON_MESSAGE" \
    --channel discord \
    --to "channel:$CHANNEL_ID" \
    --deliver \
    --isolated

echo "✓ Custom check-in cron job created for instance $INSTANCE"
echo "  - Runs hourly 9am-1am PST"
echo "  - Channel: $CHANNEL_ID"
echo "  - State file: $STATE_FILE"
