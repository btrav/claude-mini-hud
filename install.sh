#!/usr/bin/env bash
# claude-mini-hud installer
# Copies scripts to ~/.claude/ and patches ~/.claude/settings.json

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "unknown")
echo "Installing claude-mini-hud v${VERSION}..."

# ── Check dependencies ────────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed."
  echo "Install it with: brew install jq"
  exit 1
fi

# ── Create dirs ───────────────────────────────────────────────────────────────
mkdir -p "$CLAUDE_DIR/hooks"
mkdir -p "$CLAUDE_DIR/bin"

# ── Copy scripts ──────────────────────────────────────────────────────────────
cp "$SCRIPT_DIR/statusline.sh"          "$CLAUDE_DIR/statusline.sh"
cp "$SCRIPT_DIR/hooks/log-usage.sh"     "$CLAUDE_DIR/hooks/log-usage.sh"
cp "$SCRIPT_DIR/bin/claude-hud-report"  "$CLAUDE_DIR/bin/claude-hud-report"
cp "$SCRIPT_DIR/bin/claude-hud-share"   "$CLAUDE_DIR/bin/claude-hud-share"

chmod +x "$CLAUDE_DIR/statusline.sh"
chmod +x "$CLAUDE_DIR/hooks/log-usage.sh"
chmod +x "$CLAUDE_DIR/bin/claude-hud-report"
chmod +x "$CLAUDE_DIR/bin/claude-hud-share"

echo "  Copied statusline.sh       → $CLAUDE_DIR/statusline.sh"
echo "  Copied log-usage.sh        → $CLAUDE_DIR/hooks/log-usage.sh"
echo "  Copied claude-hud-report   → $CLAUDE_DIR/bin/claude-hud-report"
echo "  Copied claude-hud-share    → $CLAUDE_DIR/bin/claude-hud-share"

# ── Patch settings.json ───────────────────────────────────────────────────────
statusline_cmd="$CLAUDE_DIR/statusline.sh"
hook_cmd="$CLAUDE_DIR/hooks/log-usage.sh"

if [[ ! -f "$SETTINGS" ]]; then
  echo "{}" > "$SETTINGS"
fi

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
    if ([.hooks.Stop // [] | .[] | .hooks // [] | .[] | select(.command == $hook_cmd)] | length) == 0 then
      .hooks.Stop = (
        (.hooks.Stop // []) +
        [{
          "hooks": [{
            "type": "command",
            "command": $hook_cmd
          }]
        }]
      )
    else . end
  ' \
  "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"

echo "  Patched $SETTINGS"

# ── Add ~/.claude/bin to PATH hint ────────────────────────────────────────────
if [[ ":$PATH:" != *":$CLAUDE_DIR/bin:"* ]]; then
  case "${SHELL:-}" in
    */zsh)  rc="~/.zshrc" ;;
    */bash) rc="~/.bashrc" ;;
    *)      rc="your shell's rc file" ;;
  esac
  echo ""
  echo "  Tip: add claude-hud-report to your PATH:"
  echo "    echo 'export PATH=\"\$HOME/.claude/bin:\$PATH\"' >> $rc"
fi

echo ""
echo "Done. Start a new Claude Code session to see your HUD."
echo "Run 'claude-hud-report' for a usage summary."
