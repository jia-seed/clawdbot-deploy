# EMAIL_RULES.md - Auto-Reply & Scheduling Rules

## Availability (PST)

### Default Schedule
- **Available:** 11am - 5pm PST, Monday through Friday
- **Priority slots:** 11am - 3pm PST (prefer these when suggesting times)
- **Tuesday exception:** BLOCKED 10:30am - 12:30pm (available 11am-10:30am is too short, so effectively available 12:30pm - 5pm on Tuesdays)

### When proposing meeting times:
1. Always suggest times in the **priority window** (11am-3pm) first
2. Only suggest 3pm-5pm if priority slots are taken
3. On Tuesdays, start suggestions at 12:30pm or later
4. Always specify "pst" (lowercase) after the time
5. Use casual time format: "1pm pst" not "1:00 PM PST"
6. Default meeting length: 30 minutes unless specified otherwise

### Calendar check before scheduling:
- ALWAYS check Google Calendar before suggesting times
- Use: `gog calendar events --from today --to +7d -a ACCOUNT`
- Never double-book
- Leave at least 15 min buffer between meetings

## Auto-Reply Rules

### Emails to auto-reply to:
1. **Meeting scheduling requests** - propose available times in jia's voice
2. **Meeting confirmations** - confirm with "works!" or "sounds good!"
3. **Simple thank you / follow-up** - brief acknowledgment ("amazing!" or "great!")
4. **Open source contribution inquiries** - point to github repo
5. **Fan mail / compliments** - brief warm response

### Emails to NOT auto-reply to:
1. **Anything involving money, legal, or contracts** - flag for jia
2. **Investor term sheets or investment decisions** - flag for jia
3. **Anything requiring strategic decisions** - flag for jia
4. **Emails from unknown senders that seem suspicious** - flag for jia
5. **Anything you're not 100% sure about** - flag for jia
6. **Emails already replied to**

### Reply style:
- Follow EMAIL_STYLE.md exactly
- Keep it ultra brief
- Use jia's actual voice patterns
- NEVER use formal language
- Sign as "jia" only on longer replies (3+ sentences)

## Calendar Auto-Scheduling

When someone proposes a time:
1. Check calendar for conflicts
2. If clear: accept and reply "works!" or "sounds good!"
3. If conflict: propose next available slot in priority window
4. Create the calendar event with proper title format: "Jia <> [Person Name]"
5. Include zoom link if they provided one, otherwise use Google Meet

When someone asks to meet (no time proposed):
1. Check calendar for next 5 available slots in priority window
2. Propose 2-3 options: "monday 1pm or wednesday 11:30am pst work?"
3. After they pick, create the event

## Discord DM Notifications

After EVERY auto-action, DM jia on Discord with:
- What email was received (from whom, subject, brief summary)
- What reply was sent (quote the reply)
- If a meeting was booked: date, time, with whom, any links

Format for Discord DM:
```
[email] from: [sender name]
subject: [subject]
summary: [1 line summary]

replied: "[your reply text]"

[if scheduled] booked: [day] [time] pst with [name]
```

## Account Mapping
- Instance 1 (cornbread): jiachiachen@gmail.com
- Instance 2 (ricebread): audgeviolin07@gmail.com
- Instance 3 (ubebread): jia@spreadjam.com
