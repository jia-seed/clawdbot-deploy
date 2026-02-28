# Google Workspace (Gmail & Calendar) Setup

Enable Gmail and Google Calendar for your Clawdbot instances using the bundled `gog` skill, which wraps the [`gogcli`](https://github.com/steipete/gogcli) CLI tool.

---

## Overview

Clawdbot ships with a bundled `gog` skill that provides access to Google Workspace services (Gmail, Calendar, Drive, Contacts, Sheets, Docs). The skill auto-detects the `gog` binary — once installed, `clawdbot skills list` shows it as `✓ ready`.

Each bot instance is assigned a default Google account:

| Instance | Bot | Default Account |
|----------|-----|-----------------|
| #1 | @cornbread | jiachiachen@gmail.com |
| #2 | @ricebread | audgeviolin07@gmail.com |
| #3 | @ubebread | jia@spreadjam.com |

---

## Architecture

```
/usr/local/bin/gog                          # gogcli binary (v0.11.0, linux_arm64)
/opt/clawdbot-shared/.config/gogcli/        # shared credentials + tokens
├── credentials.json                        # OAuth client credentials
└── keyring/                                # encrypted refresh tokens
    ├── token:default:jiachiachen@gmail.com
    ├── token:default:audgeviolin07@gmail.com
    └── token:default:jia@spreadjam.com
```

All instances share a single set of OAuth credentials and tokens via `XDG_CONFIG_HOME=/opt/clawdbot-shared/.config` (set in each instance's `.env`). The systemd service's `ReadWritePaths` includes `/opt/clawdbot-shared`.

---

## Setup Guide

### Step 1: Install `gogcli` Binary

Download and install the `linux_arm64` binary from GitHub releases:

```bash
ssh root@YOUR_VM_IP '
  cd /tmp
  curl -sL https://github.com/steipete/gogcli/releases/download/v0.11.0/gogcli_0.11.0_linux_arm64.tar.gz -o gogcli.tar.gz
  tar xzf gogcli.tar.gz
  mv gog /usr/local/bin/gog
  chmod +x /usr/local/bin/gog
  rm gogcli.tar.gz
  gog --version
'
```

Expected output: `v0.11.0 (91c4c15 ...)`

Verify the skill is detected:
```bash
ssh root@YOUR_VM_IP 'HOME=/opt/clawdbot-1 \
  CLAWDBOT_STATE_DIR=/opt/clawdbot-1/.clawdbot \
  CLAWDBOT_CONFIG_PATH=/opt/clawdbot-1/.clawdbot/clawdbot.json \
  clawdbot skills list | grep gog'
```

Should show: `✓ ready │ 🎮 gog`

### Step 2: Create Google Cloud OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a project (or use an existing one)
3. Enable the **Gmail API** and **Google Calendar API**:
   - APIs & Services → Library → search "Gmail API" → Enable
   - APIs & Services → Library → search "Google Calendar API" → Enable
4. Configure the **OAuth consent screen**:
   - APIs & Services → OAuth consent screen → External → Create
   - Fill in app name, support email
   - Add scopes: `gmail.modify`, `gmail.settings.basic`, `gmail.settings.sharing`, `calendar`
   - Add your Google accounts as **test users**
   - Save
5. Create **OAuth client ID**:
   - APIs & Services → Credentials → Create Credentials → OAuth client ID
   - Application type: **Desktop app**
   - Download the `client_secret_*.json` file

### Step 3: Upload Credentials to VM

```bash
scp ~/Downloads/client_secret_*.json root@YOUR_VM_IP:/tmp/client_secret.json
```

### Step 4: Store OAuth Credentials

```bash
ssh root@YOUR_VM_IP "gog auth credentials set /tmp/client_secret.json"
```

### Step 5: Authenticate Each Google Account (Headless)

Since the VM is headless (no browser), use the `--remote` two-step flow. You also need `GOG_KEYRING_PASSWORD` set for the encrypted keyring:

```bash
# Step 1: Generate the auth URL
ssh root@YOUR_VM_IP "GOG_KEYRING_PASSWORD=clawdbot-gog-keyring \
  gog auth add YOUR_EMAIL@gmail.com --services gmail,calendar --remote --step 1"
```

This prints an `auth_url`. Open it in your browser, sign in with the Google account, and authorize. The browser will redirect to `http://127.0.0.1:XXXXX/oauth2/callback?...` — this page won't load (it's trying to reach the VM's localhost). **Copy the full URL from your browser's address bar.**

```bash
# Step 2: Exchange the code
ssh root@YOUR_VM_IP "GOG_KEYRING_PASSWORD=clawdbot-gog-keyring \
  gog auth add YOUR_EMAIL@gmail.com --services gmail,calendar --remote --step 2 \
  --auth-url 'PASTE_THE_FULL_REDIRECT_URL_HERE'"
```

Repeat for each Google account.

**Important:** Both step 1 and step 2 must use `GOG_KEYRING_PASSWORD`. If step 1 runs without it, the state is lost and you'll need to redo step 1.

### Step 6: Set Up Shared Config Directory

Copy credentials to the shared config directory accessible by the `clawdbot` user:

```bash
ssh root@YOUR_VM_IP '
  mkdir -p /opt/clawdbot-shared/.config
  cp -r /root/.config/gogcli /opt/clawdbot-shared/.config/gogcli
  chown -R clawdbot:clawdbot /opt/clawdbot-shared
'
```

### Step 7: Add Environment Variables

Add `GOG_KEYRING_PASSWORD` and `XDG_CONFIG_HOME` to each instance's `.env`:

```bash
ssh root@YOUR_VM_IP 'for i in 1 2 3; do
  echo "" >> /opt/clawdbot-$i/.env
  echo "# Google Workspace (gog) config" >> /opt/clawdbot-$i/.env
  echo "GOG_KEYRING_PASSWORD=clawdbot-gog-keyring" >> /opt/clawdbot-$i/.env
  echo "XDG_CONFIG_HOME=/opt/clawdbot-shared/.config" >> /opt/clawdbot-$i/.env
done'
```

### Step 8: Update Systemd Service

Add `/opt/clawdbot-shared` to the `ReadWritePaths` so the sandboxed service can access the shared config:

```bash
ssh root@YOUR_VM_IP "sed -i 's|ReadWritePaths=/opt/clawdbot-%i /opt/clawdbot-memory|ReadWritePaths=/opt/clawdbot-%i /opt/clawdbot-memory /opt/clawdbot-shared|' /etc/systemd/system/clawdbot@.service && systemctl daemon-reload"
```

### Step 9: Enable Skill in Clawdbot Config

Add the `gog` skill with a default Google account to each instance's `clawdbot.json`:

```bash
ssh root@YOUR_VM_IP 'python3 -c "
import json

configs = {
    1: \"jiachiachen@gmail.com\",
    2: \"audgeviolin07@gmail.com\",
    3: \"jia@spreadjam.com\"
}

for i, email in configs.items():
    path = f\"/opt/clawdbot-{i}/.clawdbot/clawdbot.json\"
    with open(path) as f:
        config = json.load(f)

    if \"skills\" not in config:
        config[\"skills\"] = {}
    if \"entries\" not in config[\"skills\"]:
        config[\"skills\"][\"entries\"] = {}

    config[\"skills\"][\"entries\"][\"gog\"] = {
        \"enabled\": True,
        \"env\": {
            \"GOG_ACCOUNT\": email
        }
    }

    with open(path, \"w\") as f:
        json.dump(config, f, indent=2)
        f.write(\"\n\")

    print(f\"Instance {i}: GOG_ACCOUNT={email}\")
"'
```

### Step 10: Fix Permissions & Restart

```bash
ssh root@YOUR_VM_IP '
  for i in 1 2 3; do chown -R clawdbot:clawdbot /opt/clawdbot-$i; done
  for i in 1 2 3; do systemctl restart clawdbot@$i; sleep 35; done
  for i in 1 2 3; do echo "Instance $i: $(systemctl is-active clawdbot@$i)"; done
'
```

---

## Verification

### Check binary
```bash
ssh root@YOUR_VM_IP "gog --version"
# v0.11.0
```

### Check tokens
```bash
ssh root@YOUR_VM_IP "GOG_KEYRING_PASSWORD=clawdbot-gog-keyring gog auth tokens list"
# token:default:audgeviolin07@gmail.com
# token:default:jia@spreadjam.com
# token:default:jiachiachen@gmail.com
```

### Test Gmail search (as clawdbot user)
```bash
ssh root@YOUR_VM_IP 'sudo -u clawdbot env \
  XDG_CONFIG_HOME=/opt/clawdbot-shared/.config \
  GOG_KEYRING_PASSWORD=clawdbot-gog-keyring \
  gog gmail search "newer_than:1d" -a jiachiachen@gmail.com --max 3'
```

### Test via Discord
```
@cornbread check my email from the last 24 hours
@ricebread what's on my calendar today?
@ubebread send an email to jiachiachen@gmail.com saying hello
```

Each bot can also access other accounts: "check jia@spreadjam.com's calendar"

---

## Adding a New Google Account

```bash
# 1. Make sure the account is added as a test user in Google Cloud Console
# 2. Run the headless auth flow
ssh root@YOUR_VM_IP "GOG_KEYRING_PASSWORD=clawdbot-gog-keyring \
  gog auth add newuser@gmail.com --services gmail,calendar --remote --step 1"
# Open URL, authorize, copy redirect URL
ssh root@YOUR_VM_IP "GOG_KEYRING_PASSWORD=clawdbot-gog-keyring \
  gog auth add newuser@gmail.com --services gmail,calendar --remote --step 2 \
  --auth-url 'REDIRECT_URL'"

# 3. Copy updated keyring to shared config
ssh root@YOUR_VM_IP "cp -r /root/.config/gogcli/keyring /opt/clawdbot-shared/.config/gogcli/ && chown -R clawdbot:clawdbot /opt/clawdbot-shared"
```

---

## Troubleshooting

### `no TTY available for keyring file backend password prompt; set GOG_KEYRING_PASSWORD`
**Cause:** The `gog` keyring needs a password to encrypt/decrypt tokens. On headless systems there's no TTY prompt.
**Fix:** Always set `GOG_KEYRING_PASSWORD=clawdbot-gog-keyring` when running `gog` commands.

### `manual auth state missing; run remote step 1 again`
**Cause:** Step 1 was run without `GOG_KEYRING_PASSWORD`, so the auth state couldn't be persisted.
**Fix:** Re-run step 1 with `GOG_KEYRING_PASSWORD` set, get a new URL, and redo the flow.

### `gog` skill shows `✗ missing` in `clawdbot skills list`
**Cause:** The `gog` binary isn't installed or isn't in PATH.
**Fix:** Install it to `/usr/local/bin/gog` (see Step 1).

### Gmail/Calendar commands fail with permission errors
**Cause:** The `clawdbot` user can't access the shared config directory.
**Fix:**
```bash
ssh root@YOUR_VM_IP "chown -R clawdbot:clawdbot /opt/clawdbot-shared"
```
Also verify `ReadWritePaths` in the systemd service includes `/opt/clawdbot-shared`.

### Token refresh fails
**Cause:** OAuth tokens expire. The refresh token should auto-renew, but if the Google Cloud project is in test mode, refresh tokens expire after 7 days.
**Fix:** Either move the OAuth consent screen to production (requires Google review) or re-authorize:
```bash
ssh root@YOUR_VM_IP "GOG_KEYRING_PASSWORD=clawdbot-gog-keyring \
  gog auth add user@gmail.com --services gmail,calendar --remote --step 1 --force-consent"
```

---

## Reference

- [gogcli GitHub](https://github.com/steipete/gogcli)
- [Google Cloud Console](https://console.cloud.google.com)
- OAuth Client ID: `177344916707-ednmqjqa7a3161rs5er0frgavevc0kvl.apps.googleusercontent.com`
- Keyring password: `clawdbot-gog-keyring`
- Shared config path: `/opt/clawdbot-shared/.config/gogcli/`
