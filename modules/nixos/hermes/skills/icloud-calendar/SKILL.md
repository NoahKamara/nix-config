---
name: icloud-calendar
description: "Read and write iCloud Calendar via CalDAV (vdirsyncer + khal)."
version: 1.0.0
author: noah
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [Calendar, iCloud, CalDAV, Productivity]
---

# iCloud Calendar

Syncs iCloud Calendar to local `.ics` files with **vdirsyncer**, then lists/creates/edits events with **khal**.

Tools live at `/data/bin/vdirsyncer` and `/data/bin/khal` (Nix-managed, available in the Hermes container).

**Note:** iCloud Reminder lists (Einkauf, To Do, etc.) also show up over CalDAV. Only event calendars are configured for sync — not reminders. For tasks, use Todoist or another task integration.

## Workflow

Always sync before reading and after writing:

```bash
/data/bin/vdirsyncer sync
```

## List events

```bash
/data/bin/khal list                        # today
/data/bin/khal list today 7d               # next 7 days
/data/bin/khal list 2026-05-30 2026-06-06  # date range
/data/bin/khal search "dentist"
```

## Create events

Use ISO dates and 24h times. Sync after creating.

```bash
# Timed event: khal new START-DATE START-TIME END-DATE END-TIME "Title"
/data/bin/khal new 2026-05-30 10:00 2026-05-30 11:00 "Team standup"

# All-day event
/data/bin/khal new 2026-05-30 "Birthday party"

# With location
/data/bin/khal new 2026-05-30 12:00 2026-05-30 13:00 "Lunch" --location "Cafe"

/data/bin/vdirsyncer sync
```

## First-time setup

If `vdirsyncer sync` fails with an undiscovered collections error, run once (answer **y** only for event calendars, **n** for Reminder lists like Einkauf/To Do):

```bash
yes | /data/bin/vdirsyncer discover
/data/bin/vdirsyncer sync
```

## Rules

1. **Confirm before creating or deleting events** — show title, start, end, and calendar first.
2. **Always run `vdirsyncer sync`** after local changes so iCloud stays in sync.
3. **`khal edit` is interactive** — prefer `khal new` for agent-driven creates; use edit only when the user is at a TTY.
4. Times are local unless you pass an explicit timezone flag.
