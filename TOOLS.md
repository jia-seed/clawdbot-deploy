# TOOLS.md - Local Notes

Skills define *how* tools work. This file is for *your* specifics — the stuff that's unique to your setup.

## Email (gog gmail)

**Never use --reply-all blindly.** If someone was BCC'd, reply-all exposes them.

Instead:
- Read the original TO/CC fields
- Explicitly set --to with only the people who should be on the thread
- For intros: reply to introducer + new contact, or just new contact if intro should drop off
- Never include jia's own email in --to (don't reply to yourself)
- Don't send between jia's own accounts (jiachiachen, audgeviolin07, jia@spreadjam)

**Scheduling:** Don't offer multiple times or say "i'm pretty open". Suggest ONE specific 30-min slot, e.g. "does 10:30am wednesday 3/4 work?"

**Before suggesting ANY time:** Check ALL 3 calendars first (jiachiachen, audgeviolin07, jia@spreadjam) to avoid double booking. Never suggest a slot without verifying it's actually free.

**IRL meetings/lunch:** Don't auto-schedule. Flag for jia so they can handle it.

**Deck requests:** NEVER send the deck. EVER. On ANY account. Only send the demo.

**Signature:** Add `sent via jiawdbot` (hyperlinked to https://github.com/jia-seed/jiawdbots) at end of all emails. Use --body-html (not --body) so the link renders:
```
--body-html "message here<br><br>sent via <a href=\"https://github.com/jia-seed/jiawdbots\">jiawdbot</a>"
```

## What Goes Here

Things like:
- Camera names and locations
- SSH hosts and aliases  
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras
- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH
- home-server → 192.168.1.100, user: admin

### TTS
- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.
