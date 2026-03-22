# claude-mini-hud

A terminal HUD for Claude Code showing context usage, session rate limit, and session duration — directly in the Claude Code status line.

```
✦CC✦ ▓▓▓▓▓▓░░░░ 61% · ▮▮▮▮▯ · 23m
```

## What each segment means

| Segment | Metric | Behavior |
|---|---|---|
| `✦CC✦` | Callsign | Changes based on urgency state |
| `▓▓▓▓▓▓░░░░ 61%` | Context window fill | Fills up as conversation grows |
| `▮▮▮▮▯` | 5-hour rate limit battery | Drains as you use your session allowance |
| `23m` | Session duration | Wall-clock time since session start |
| `+142 -38` | Lines changed | Shown when non-zero |
| `🔥5d` | Streak | Days in a row with a Claude Code session |

## State-aware callsign

| Callsign | Meaning |
|---|---|
| `✦CC✦` | Normal (dim) |
| `◈CC◈` | Context warming up (70–89%, amber) |
| `!CC!` | Context critical or rate limit exhausted (red) |

## Color thresholds

**Context window** — fills with a color cascade (segments shift green → amber → red)
- Segments 1–6: green
- Segments 7–8: amber
- Segments 9–10: red

**Rate limit battery**
- Green above 20% remaining
- Amber at 20% or below (remaining % shown next to battery)
- Red at 5% or below

## HUD states

**Fresh session:**
```
✦CC✦ ▓▓░░░░░░░░ 18% · ▮▮▮▮▮ · 4m
```

**Mid-session, context warming up:**
```
◈CC◈ ▓▓▓▓▓▓▓░░░ 74% · ▮▮▮▮▯ · 41m · +88 -12
```

**Context critical (red):**
```
!CC! ▓▓▓▓▓▓▓▓▓░ 91% · ▮▮▮▮▮ · 1h 12m
```

**Rate limit running low, streak active:**
```
✦CC✦ ▓▓▓▓░░░░░░ 38% · ▮▮▯▯▯ 18% · 3h 48m · 🔥7d
```

## Themes

Set `CLAUDE_HUD_THEME` in your shell (add to `~/.zshrc`):

```bash
export CLAUDE_HUD_THEME=synthwave
```

| Theme | Colors |
|---|---|
| `default` | Green / amber / red |
| `synthwave` | Magenta / cyan / hot-pink |
| `ghost` | All dim white/grey |
| `matrix` | Bright green / green / dim green |
| `blueprint` | Bright blue / blue / dim blue |

> Note: `synthwave` uses 256-color mode — requires a terminal with 256-color support.

## Usage report

Run `claude-hud-report` for a session summary:

```
✦CC✦  claude-mini-hud · Last 7 days
─────────────────────────────
Sessions:   12
Tokens in:  145230
Tokens out: 48910
Peak ctx:   89%
Models:     claude-sonnet-4-6 (11), claude-opus-4-6 (1)
─────────────────────────────
```

Flags: `--today`, `--week` (default), `--month`, `--all`

## Debugging

If the usage log shows zero tokens, enable debug mode to inspect the raw Stop hook payload:

```bash
export CLAUDE_HUD_DEBUG=1
```

Raw hook data is appended to `~/.claude/hud-debug.jsonl`. Inspect with:

```bash
cat ~/.claude/hud-debug.jsonl | jq .
```

## Requirements

- [Claude Code](https://claude.ai/code)
- [jq](https://jqlang.github.io/jq/) — `brew install jq`
- bash

## Install

```bash
git clone https://github.com/btrav/claude-mini-hud.git
cd claude-mini-hud
chmod +x install.sh
./install.sh
```

Add `claude-hud-report` to your PATH:

```bash
echo 'export PATH="$HOME/.claude/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Then start a new Claude Code session.

## Manual install

1. Copy `statusline.sh` to `~/.claude/statusline.sh` and make it executable
2. Copy `hooks/log-usage.sh` to `~/.claude/hooks/log-usage.sh` and make it executable
3. Copy `bin/claude-hud-report` to `~/.claude/bin/claude-hud-report` and make it executable
4. Add to `~/.claude/settings.json`:

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

The Stop hook appends a record to `~/.claude/usage-log.jsonl` at the end of each session:

```json
{"ts":1742563200,"session_id":"abc123","tokens_in":45231,"tokens_out":12847,"cost_usd":null,"lines_added":null,"lines_removed":null,"ctx_pct":0,"duration_ms":0,"model":"claude-sonnet-4-6"}
```

> Note: `cost_usd`, `lines_added`, `lines_removed`, `ctx_pct`, and `duration_ms` are not available in the Stop hook payload. Token counts are parsed from the session transcript file.

## Uninstall

```bash
./uninstall.sh
```

Removes all scripts and cleans up `~/.claude/settings.json` without touching other hooks or settings. Your usage log at `~/.claude/usage-log.jsonl` is preserved.
