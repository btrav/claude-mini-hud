#!/usr/bin/env bash
# claude-hud Stop hook
# Appends session usage data to ~/.claude/usage-log.jsonl on session end

LOG="$HOME/.claude/usage-log.jsonl"

input=$(cat 2>/dev/null)
[[ -z "$input" ]] && exit 0
echo "$input" | jq -e . >/dev/null 2>&1 || exit 0

# Append a single JSON record per session
jq -c '{
  ts:          (now | floor),
  session_id:  (.session_id // null),
  ctx_pct:     (.context_window.used_percentage // 0),
  tokens_in:   (.context_window.total_input_tokens // 0),
  tokens_out:  (.context_window.total_output_tokens // 0),
  duration_ms: (.cost.total_duration_ms // 0)
}' <<< "$input" >> "$LOG" 2>/dev/null

# Rotate log if it exceeds 10,000 lines
line_count=$(wc -l < "$LOG" 2>/dev/null || echo 0)
if (( line_count > 10000 )); then
  tail -n 5000 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi
