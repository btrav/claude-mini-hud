# claude-mini-hud

A terminal HUD for Claude Code that shows context usage, session rate limit, and session duration — directly in the Claude Code status line.

```
✦CC✦ ▓▓▓▓▓▓░░░░ 61% · ▮▮▮▮▯ · 23m
```

## What each segment means

| Segment | Metric | Behavior |
|---|---|---|
| `✦CC✦` | Callsign | Static label |
| `▓▓▓▓▓▓░░░░ 61%` | Context window fill | Fills up as conversation grows. Compact when this gets high. |
| `▮▮▮▮▯` | 5-hour rate limit battery | Drains as you use your session allowance |
| `23m` | Session duration | Wall-clock time since session start |

## Color thresholds

**Context window**
- Green below 70%
- Amber 70–89%
- Red 90%+

**Rate limit battery**
- Green above 20% remaining
- Amber at 20% or below
- Red at 5% or below

## HUD states

**Fresh session:**
```
✦CC✦ ▓▓░░░░░░░░ 18% · ▮▮▮▮▮ · 4m
```

**Mid-session, context warming up:**
```
✦CC✦ ▓▓▓▓▓▓▓░░░ 74% · ▮▮▮▮▯ · 41m
```

**Context nearly full (red), compact soon:**
```
✦CC✦ ▓▓▓▓▓▓▓▓▓░ 91% · ▮▮▮▮▮ · 1h 12m
```

**Rate limit running low (amber battery):**
```
✦CC✦ ▓▓▓▓░░░░░░ 38% · ▮▮▯▯▯ · 3h 48m
```

## Requirements

- [Claude Code](https://claude.ai/code)
- [jq](https://jqlang.github.io/jq/) — `brew install jq`
- bash

## Install

```bash
git clone https://github.com/yourusername/claude-mini-hud.git
cd claude-mini-hud
chmod +x install.sh
./install.sh
```

Then start a new Claude Code session.

## Manual install

1. Copy `statusline.sh` to `~/.claude/statusline.sh` and make it executable
2. Copy `hooks/log-usage.sh` to `~/.claude/hooks/log-usage.sh` and make it executable
3. Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/Users/yourname/.claude/statusline.sh"
  },
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/Users/yourname/.claude/hooks/log-usage.sh"
          }
        ]
      }
    ]
  }
}
```

## Usage log

The Stop hook appends a record to `~/.claude/usage-log.jsonl` at the end of each session. Each line looks like:

```json
{"ts":1742563200,"session_id":"abc123","ctx_pct":74,"tokens_in":45231,"tokens_out":12847,"duration_ms":2580000}
```

Query it with jq. Example — sessions from the last 7 days:

```bash
jq -s 'map(select(.ts > now - 604800))' ~/.claude/usage-log.jsonl
```

## Uninstall

```bash
rm ~/.claude/statusline.sh
rm ~/.claude/hooks/log-usage.sh
```

Then remove the `statusLine` and `hooks.Stop` entries from `~/.claude/settings.json`.
