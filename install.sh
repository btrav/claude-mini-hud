#!/usr/bin/env bash
# claude-mini-hud installer
# Copies scripts to ~/.claude/ and patches ~/.claude/settings.json

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing claude-mini-hud..."

# ── Check dependencies ─────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed."
  echo "Install it with: brew install jq"
  exit 1
fi

# ── Create dirs ────────────────────────────────────────────────────────────
mkdir -p "$CLAUDE_DIR/hooks"

# ── Copy scripts ───────────────────────────────────────────────────────────
cp "$SCRIPT_DIR/statusline.sh"       "$CLAUDE_DIR/statusline.sh"
cp "$SCRIPT_DIR/hooks/log-usage.sh"  "$CLAUDE_DIR/hooks/log-usage.sh"

chmod +x "$CLAUDE_DIR/statusline.sh"
chmod +x "$CLAUDE_DIR/hooks/log-usage.sh"

echo "  Copied statusline.sh → $CLAUDE_DIR/statusline.sh"
echo "  Copied log-usage.sh  → $CLAUDE_DIR/hooks/log-usage.sh"

# ── Patch settings.json ────────────────────────────────────────────────────
statusline_cmd="$CLAUDE_DIR/statusline.sh"
hook_cmd="$CLAUDE_DIR/hooks/log-usage.sh"

# Create settings.json if it doesn't exist
if [[ ! -f "$SETTINGS" ]]; then
  echo "{}" > "$SETTINGS"
fi

# Merge statusLine and Stop hook into existing settings
jq \
  --arg sl_cmd "$statusline_cmd" \
  --arg hook_cmd "$hook_cmd" \
  '
    . + {
      "statusLine": {
        "type": "command",
        "command": $sl_cmd
      }
    } |
    .hooks.Stop = (
      (.hooks.Stop // []) +
      [{
        "hooks": [{
          "type": "command",
          "command": $hook_cmd
        }]
      }]
    )
  ' \
  "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"

echo "  Patched $SETTINGS"
echo ""
echo "Done. Start a new Claude Code session to see your HUD."
