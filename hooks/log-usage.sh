#!/usr/bin/env bash
# claude-mini-hud Stop hook
# Appends session usage data to ~/.claude/usage-log.jsonl on session end
#
# Note: The Stop hook payload contains session metadata but NOT cost, context,
# or rate limit data. Token counts are parsed from the session transcript.
#
# Debug mode: set CLAUDE_HUD_DEBUG=1 to dump raw stdin to ~/.claude/hud-debug.jsonl

LOG="$HOME/.claude/usage-log.jsonl"
DEBUG_LOG="$HOME/.claude/hud-debug.jsonl"

input=$(cat 2>/dev/null)
[[ -z "$input" ]] && exit 0
echo "$input" | jq -e . >/dev/null 2>&1 || exit 0

# ── Debug mode ───────────────────────────────────────────────────────────────
if [[ "${CLAUDE_HUD_DEBUG:-0}" == "1" ]]; then
  jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '. + {_debug_ts: $ts}' <<< "$input" >> "$DEBUG_LOG" 2>/dev/null
fi

# ── Extract session metadata ──────────────────────────────────────────────────
session_id=$(jq -r '.session_id // ""' <<< "$input" 2>/dev/null)
transcript=$(jq -r '.transcript_path // ""' <<< "$input" 2>/dev/null)

# ── Parse token data from transcript ─────────────────────────────────────────
# The Stop hook doesn't carry cost/context data. Parse it from the transcript file.
tokens_in=0; tokens_out=0; model=""

if [[ -n "$transcript" && -f "$transcript" ]]; then
  read -r tokens_in tokens_out model <<< "$(
    jq -rs '
      [.[] | select(.type == "assistant" and .message != null)] |
      {
        ti: (map(.message.usage.input_tokens  // 0) | add // 0),
        to: (map(.message.usage.output_tokens // 0) | add // 0),
        m:  (map(.message.model // "") | last // "")
      } | [.ti, .to, .m] | @tsv
    ' "$transcript" 2>/dev/null
  )"
fi

tokens_in=${tokens_in:-0}
tokens_out=${tokens_out:-0}
model=${model:-""}

# ── Pull ctx_pct, duration, and lines from statusline state ──────────────────
# The Stop hook payload doesn't carry these, but the statusline writes them to
# hud-state.tsv after every render. If the cached session_id matches this Stop
# event, the cached values belong to this session.
ctx_pct=0; duration_ms=0; lines_added=null; lines_removed=null
STATE_FILE="$HOME/.claude/hud-state.tsv"
if [[ -f "$STATE_FILE" && -n "$session_id" ]]; then
  IFS=$'\t' read -r s_ctx _ s_dur s_la s_lr _ _ _ _ s_sid < "$STATE_FILE" 2>/dev/null
  if [[ "${s_sid:-}" == "$session_id" ]]; then
    ctx_pct=${s_ctx:-0}
    duration_ms=${s_dur:-0}
    lines_added=${s_la:-null}
    lines_removed=${s_lr:-null}
  fi
fi

# ── Append log record ─────────────────────────────────────────────────────────
jq -nc \
  --argjson ts "$(date +%s)" \
  --arg session_id "$session_id" \
  --argjson tokens_in "${tokens_in}" \
  --argjson tokens_out "${tokens_out}" \
  --argjson ctx_pct "${ctx_pct}" \
  --argjson duration_ms "${duration_ms}" \
  --argjson lines_added "${lines_added}" \
  --argjson lines_removed "${lines_removed}" \
  --arg model "$model" \
  '{
    ts:            $ts,
    session_id:    $session_id,
    tokens_in:     $tokens_in,
    tokens_out:    $tokens_out,
    cost_usd:      null,
    lines_added:   $lines_added,
    lines_removed: $lines_removed,
    ctx_pct:       $ctx_pct,
    duration_ms:   $duration_ms,
    model:         $model
  }' >> "$LOG" 2>/dev/null

# ── Rotate log if it exceeds 10,000 lines ────────────────────────────────────
line_count=$(wc -l < "$LOG" 2>/dev/null || echo 0)
if (( line_count > 10000 )); then
  tail -n 5000 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi
