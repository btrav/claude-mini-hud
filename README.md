<h1 align="center">claude-mini-hud</h1>

<p align="center">
  Your terminal. Claude's context. No surprises.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-brightgreen" alt="MIT License">
  <img src="https://img.shields.io/badge/shell-bash-blue" alt="bash">
  <img src="https://img.shields.io/badge/platform-macOS%20%2F%20Linux-lightgrey" alt="macOS / Linux">
  <img src="https://img.shields.io/badge/requires-Claude%20Code-orange" alt="Claude Code">
</p>

---

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  ✦CC✦  ▓▓▓▓▓▓░░░░  61%  ·  ▮▮▮▮▯  ·  23m  ·  +142 -38  ·  ♨5d  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

A live HUD for [Claude Code](https://claude.ai/code) that shows context window fill, rate limit battery, session time, lines changed, and streak — in Claude Code's native status bar. No extra panes. No config files to learn. One install.

---

## install

```bash
git clone https://github.com/btrav/claude-mini-hud.git && cd claude-mini-hud && ./install.sh
```

Add CLI tools to your PATH:

```bash
echo 'export PATH="$HOME/.claude/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

Start a new Claude Code session. Done.

---

## what you're looking at

```
  ✦CC✦  ▓▓▓▓▓▓░░░░  61%  ·  ▮▮▮▮▯  ·  23m  ·  +142 -38  ·  ♨5d
  ────  ─────────────────  ─────────  ─────  ───────────  ────
  state    context bar       battery   time    code diff   streak
```

**Context bar** — fills as the conversation grows. Green → amber → red as Claude's working memory gets tight. When it maxes out, Claude Code compacts. Use `/compact` to control it manually.

**Battery** — your 5-hour rate limit window. Drains over time, goes amber at 20% remaining and red at 5%. Shows time until reset when low (`~1h 20m`).

**Callsign** — reads session state at a glance:

```
  normal              warning             critical
  ✦CC✦                ◈CC◈                !CC!
  ▓▓░░░░░░░░  18%     ▓▓▓▓▓▓▓░░░  74%    ▓▓▓▓▓▓▓▓▓░  91%
  ▮▮▮▮▮               ▮▮▮▮▯ ~1h           ▮▮▮▯▯ ~22m
```

---

## themes

```bash
export CLAUDE_HUD_THEME=synthwave   # add to ~/.zshrc
```

```
  default    green → amber → red
  ✦CC✦  ▓▓▓▓▓▓░░░░  61%  ·  ▮▮▮▮▯  ·  23m  ·  ♨5d

  synthwave  magenta → cyan → hot-pink
  ✦CC✦  ▓▓▓▓▓▓░░░░  61%  ·  ▮▮▮▮▯  ·  23m  ·  ♨5d

  ghost      all dim white/grey
  ✦CC✦  ▓▓▓▓▓▓░░░░  61%  ·  ▮▮▮▮▯  ·  23m  ·  ♨5d

  matrix     bright green → green → dim green
  ✦CC✦  ▓▓▓▓▓▓░░░░  61%  ·  ▮▮▮▮▯  ·  23m  ·  ♨5d

  blueprint  bright blue → blue → dim blue
  ✦CC✦  ▓▓▓▓▓▓░░░░  61%  ·  ▮▮▮▮▯  ·  23m  ·  ♨5d
```

> `synthwave` uses 256-color mode — requires a terminal with 256-color support.

---

## flex your session

After a long session, run:

```bash
claude-hud-share
```

```
  ┌──────────────────────────────────┐
  │  ✦CC✦  claude-mini-hud           │
  ├──────────────────────────────────┤
  │  ctx   ▓▓▓▓▓▓▓░░░  74%          │
  │  time  1h 43m                    │
  │  lines +312 -47                  │
  │  ♨ 12 day streak                 │
  │  claude-sonnet-4-6               │
  ├──────────────────────────────────┤
  │  github.com/btrav/claude-mini-hud│
  └──────────────────────────────────┘
```

`claude-hud-share --copy` copies plain-text to clipboard. Screenshot and post it.

---

## usage report

```bash
claude-hud-report            # last 7 days (default)
claude-hud-report --today
claude-hud-report --month
claude-hud-report --all
```

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

---

## does it add latency?

The status line runs after every Claude response, not during. It reads a JSON payload, does bash arithmetic, writes one line. Under 30ms on a modern Mac. You won't notice it.

---

## requirements

- [Claude Code](https://claude.ai/code)
- [jq](https://jqlang.github.io/jq/) — `brew install jq`
- bash

---

## manual install

1. Copy `statusline.sh` → `~/.claude/statusline.sh` (executable)
2. Copy `hooks/log-usage.sh` → `~/.claude/hooks/log-usage.sh` (executable)
3. Copy `bin/claude-hud-report` and `bin/claude-hud-share` → `~/.claude/bin/` (executable)
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

---

## debugging

If the usage log shows zero tokens, enable debug mode:

```bash
export CLAUDE_HUD_DEBUG=1
```

Raw Stop hook data appends to `~/.claude/hud-debug.jsonl`. Inspect with `cat ~/.claude/hud-debug.jsonl | jq .`

> The Claude Code Stop hook doesn't carry cost or context data — only session metadata. Token counts are parsed from the session transcript. Fields like `cost_usd` and `lines_added` are null in the log for this reason.

---

## uninstall

```bash
./uninstall.sh
```

Removes scripts and cleans `~/.claude/settings.json` without touching your other hooks or settings. Usage log at `~/.claude/usage-log.jsonl` is preserved.
