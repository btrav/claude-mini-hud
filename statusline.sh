#!/usr/bin/env bash
# claude-hud statusline script
# Reads Claude Code session JSON from stdin, outputs a formatted HUD line

# ANSI colors
GREEN='\033[32m'
AMBER='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

# Fail silently on empty or malformed input
input=$(cat 2>/dev/null)
[[ -z "$input" ]] && exit 0
echo "$input" | jq -e . >/dev/null 2>&1 || exit 0

# Extract all values in a single jq call (integers only)
read -r ctx_pct rate_used duration_ms <<< "$(
  echo "$input" | jq -r '[
    (.context_window.used_percentage // 0 | floor),
    (.rate_limits.five_hour.used_percentage // 0 | floor),
    (.cost.total_duration_ms // 0 | floor)
  ] | @tsv' 2>/dev/null
)"

# Guard against missing values
[[ -z "$ctx_pct" ]]    && ctx_pct=0
[[ -z "$rate_used" ]]  && rate_used=0
[[ -z "$duration_ms" ]] && duration_ms=0

# ── Context window bar (10 segments, fills up) ─────────────────────────────
ctx_filled=$(( ctx_pct * 10 / 100 ))
ctx_bar=""
for (( i=1; i<=10; i++ )); do
  (( i <= ctx_filled )) && ctx_bar+="▓" || ctx_bar+="░"
done

if   (( ctx_pct >= 90 )); then ctx_color="$RED"
elif (( ctx_pct >= 70 )); then ctx_color="$AMBER"
else                           ctx_color="$GREEN"
fi

# ── Session rate limit battery (5 segments, drains) ───────────────────────
rate_remaining=$(( 100 - rate_used ))
(( rate_remaining < 0 )) && rate_remaining=0

battery_filled=$(( rate_remaining * 5 / 100 ))
battery=""
for (( i=1; i<=5; i++ )); do
  (( i <= battery_filled )) && battery+="▮" || battery+="▯"
done

if   (( rate_remaining <= 5  )); then bat_color="$RED"
elif (( rate_remaining <= 20 )); then bat_color="$AMBER"
else                                  bat_color="$GREEN"
fi

# ── Session duration ───────────────────────────────────────────────────────
total_secs=$(( duration_ms / 1000 ))
total_mins=$(( total_secs / 60 ))

if   (( total_mins <= 0  )); then duration_str="<1m"
elif (( total_mins >= 60 )); then
  hours=$(( total_mins / 60 ))
  mins=$(( total_mins % 60 ))
  duration_str="${hours}h ${mins}m"
else
  duration_str="${total_mins}m"
fi

# ── Output ─────────────────────────────────────────────────────────────────
printf "${DIM}✦CC✦${RESET} ${ctx_color}${ctx_bar} %3d%%${RESET} ${DIM}·${RESET} ${bat_color}${battery}${RESET} ${DIM}·${RESET} ${DIM}${duration_str}${RESET}\n" "$ctx_pct"
