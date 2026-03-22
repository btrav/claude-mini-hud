#!/usr/bin/env bash
# claude-mini-hud statusline script
# Reads Claude Code session JSON from stdin, outputs a formatted HUD line

# ── Fail silently on bad input ──────────────────────────────────────────────
input=$(cat 2>/dev/null)
[[ -z "$input" ]] && exit 0
echo "$input" | jq -e . >/dev/null 2>&1 || exit 0

# ── Theme ────────────────────────────────────────────────────────────────────
# Set CLAUDE_HUD_THEME in your shell: default | synthwave | ghost | matrix | blueprint
case "${CLAUDE_HUD_THEME:-default}" in
  synthwave)
    C_LOW='\033[35m'; C_MID='\033[36m'; C_HIGH='\033[38;5;201m' ;;
  ghost)
    C_LOW='\033[2;37m'; C_MID='\033[2;37m'; C_HIGH='\033[37m' ;;
  matrix)
    C_LOW='\033[92m'; C_MID='\033[32m'; C_HIGH='\033[2;32m' ;;
  blueprint)
    C_LOW='\033[94m'; C_MID='\033[34m'; C_HIGH='\033[2;34m' ;;
  *)
    C_LOW='\033[32m'; C_MID='\033[33m'; C_HIGH='\033[31m' ;;
esac
C_DIM='\033[2m'
C_RESET='\033[0m'

# ── Extract all values in a single jq call ───────────────────────────────────
read -r ctx_pct rate_used duration_ms lines_added lines_removed <<< "$(
  echo "$input" | jq -r '[
    (.context_window.used_percentage        // 0 | floor),
    (.rate_limits.five_hour.used_percentage // 0 | floor),
    (.cost.total_duration_ms                // 0 | floor),
    (.cost.total_lines_added                // 0 | floor),
    (.cost.total_lines_removed              // 0 | floor)
  ] | @tsv' 2>/dev/null
)"
ctx_pct=${ctx_pct:-0}; rate_used=${rate_used:-0}; duration_ms=${duration_ms:-0}
lines_added=${lines_added:-0}; lines_removed=${lines_removed:-0}

# ── Derived values ───────────────────────────────────────────────────────────
rate_remaining=$(( 100 - rate_used ))
(( rate_remaining < 0 )) && rate_remaining=0

# ── State-aware callsign ─────────────────────────────────────────────────────
if   (( ctx_pct >= 90 || rate_remaining <= 5 )); then
  callsign_str="${C_HIGH}!CC!${C_RESET}"
elif (( ctx_pct >= 70 )); then
  callsign_str="${C_MID}◈CC◈${C_RESET}"
else
  callsign_str="${C_DIM}✦CC✦${C_RESET}"
fi

# ── Context bar with color cascade (10 segments, fills up) ───────────────────
# Segments 1-6: C_LOW, 7-8: C_MID, 9-10: C_HIGH
ctx_filled=$(( ctx_pct * 10 / 100 ))
ctx_bar=""
for (( i=1; i<=10; i++ )); do
  if (( i <= ctx_filled )); then
    if   (( i <= 6 )); then ctx_bar+="${C_LOW}▓${C_RESET}"
    elif (( i <= 8 )); then ctx_bar+="${C_MID}▓${C_RESET}"
    else                    ctx_bar+="${C_HIGH}▓${C_RESET}"
    fi
  else
    ctx_bar+="${C_DIM}░${C_RESET}"
  fi
done

# Percentage label color matches cascade frontier
if   (( ctx_pct >= 90 )); then ctx_num_color="$C_HIGH"
elif (( ctx_pct >= 70 )); then ctx_num_color="$C_MID"
else                           ctx_num_color="$C_LOW"
fi
printf -v ctx_pct_str '%3d%%' "$ctx_pct"

# ── Session rate limit battery (5 segments, drains) ──────────────────────────
battery_filled=$(( rate_remaining * 5 / 100 ))
battery=""
for (( i=1; i<=5; i++ )); do
  (( i <= battery_filled )) && battery+="▮" || battery+="▯"
done

if   (( rate_remaining <= 5  )); then bat_color="$C_HIGH"
elif (( rate_remaining <= 20 )); then bat_color="$C_MID"
else                                  bat_color="$C_LOW"
fi

# Show remaining % when amber or red
bat_pct_str=""
(( rate_remaining <= 20 )) && bat_pct_str=" ${rate_remaining}%"

# ── Session duration ──────────────────────────────────────────────────────────
total_mins=$(( duration_ms / 60000 ))
if   (( total_mins <= 0  )); then duration_str="<1m"
elif (( total_mins >= 60 )); then duration_str="$((total_mins/60))h $((total_mins%60))m"
else                              duration_str="${total_mins}m"
fi

# ── Lines changed (only shown when non-zero) ─────────────────────────────────
diff_str=""
if (( lines_added > 0 || lines_removed > 0 )); then
  diff_str=" ${C_DIM}·${C_RESET} ${C_LOW}+${lines_added}${C_RESET} ${C_HIGH}-${lines_removed}${C_RESET}"
fi

# ── Streak counter ────────────────────────────────────────────────────────────
STREAK_FILE="$HOME/.claude/hud-streak"
today=$(date +%Y-%m-%d)
yesterday=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d 2>/dev/null)

if [[ -f "$STREAK_FILE" ]]; then
  read -r s_date s_count < "$STREAK_FILE" 2>/dev/null
  s_count=${s_count:-0}
  if   [[ "$s_date" == "$today"     ]]; then : # same day, no change
  elif [[ "$s_date" == "$yesterday" ]]; then
    s_count=$(( s_count + 1 ))
    printf '%s %d\n' "$today" "$s_count" > "$STREAK_FILE"
  else
    s_count=1
    printf '%s 1\n' "$today" > "$STREAK_FILE"
  fi
else
  s_count=1
  printf '%s 1\n' "$today" > "$STREAK_FILE"
fi

streak_str=""
(( s_count > 1 )) && streak_str=" ${C_DIM}·${C_RESET} ${C_MID}🔥${s_count}d${C_RESET}"

# ── Output ────────────────────────────────────────────────────────────────────
out="${callsign_str} ${ctx_bar} ${ctx_num_color}${ctx_pct_str}${C_RESET} ${C_DIM}·${C_RESET} ${bat_color}${battery}${bat_pct_str}${C_RESET} ${C_DIM}·${C_RESET} ${C_DIM}${duration_str}${C_RESET}${diff_str}${streak_str}"
printf '%b\n' "$out"
