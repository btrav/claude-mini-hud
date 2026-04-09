#!/usr/bin/env bash
# claude-mini-hud uninstaller
# Removes scripts from ~/.claude/ and cleans up settings.json

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

echo "Uninstalling claude-mini-hud..."

# ── Check dependencies ────────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required for settings cleanup."
  echo "Install it with: brew install jq"
  exit 1
fi

# ── Remove scripts ────────────────────────────────────────────────────────────
files=(
  "$CLAUDE_DIR/statusline.sh"
  "$CLAUDE_DIR/hooks/log-usage.sh"
  "$CLAUDE_DIR/bin/claude-hud-report"
  "$CLAUDE_DIR/bin/claude-hud-share"
  "$CLAUDE_DIR/hud-streak"
  "$CLAUDE_DIR/hud-state.tsv"
  "$CLAUDE_DIR/hud-compact"
  "$CLAUDE_DIR/hud-notify-state"
)
for f in "${files[@]}"; do
  if [[ -f "$f" ]]; then
    rm "$f" && echo "  Removed $f"
  fi
done

# ── Patch settings.json ───────────────────────────────────────────────────────
if [[ -f "$SETTINGS" ]]; then
  hook_cmd="$CLAUDE_DIR/hooks/log-usage.sh"
  statusline_cmd="$CLAUDE_DIR/statusline.sh"

  jq \
    --arg sl_cmd "$statusline_cmd" \
    --arg hook_cmd "$hook_cmd" \
    '
      if (.statusLine.command == $sl_cmd) then del(.statusLine) else . end |
      if .hooks.Stop then
        .hooks.Stop |= map(
          .hooks |= map(select(.command != $hook_cmd))
        ) |
        .hooks.Stop |= map(select((.hooks | length) > 0)) |
        if ((.hooks.Stop | length) == 0) then del(.hooks.Stop) else . end |
        if ((.hooks | keys | length) == 0) then del(.hooks) else . end
      else . end
    ' \
    "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"

  echo "  Cleaned up $SETTINGS"
fi

echo ""
echo "Done. Usage log preserved at $HOME/.claude/usage-log.jsonl"
echo "Remove it manually if you don't need it: rm ~/.claude/usage-log.jsonl"
