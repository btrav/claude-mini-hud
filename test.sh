#!/usr/bin/env bash
# claude-mini-hud smoke tests
# Pipes known JSON fixtures into statusline.sh and checks output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS="$SCRIPT_DIR/statusline.sh"
PASS=0; FAIL=0

# Disable notifications in tests
export CLAUDE_HUD_NOTIFY=0

# Clean up temp state files so they don't interfere
cleanup() {
  rm -f "$HOME/.claude/hud-compact" "$HOME/.claude/hud-notify-state"
}
trap cleanup EXIT
cleanup

assert_contains() {
  local label="$1" output="$2" expected="$3"
  # Strip ANSI codes for matching
  local plain
  plain=$(printf '%b' "$output" | sed 's/\x1b\[[0-9;]*m//g')
  if [[ "$plain" == *"$expected"* ]]; then
    echo "  PASS  $label"
    PASS=$(( PASS + 1 ))
  else
    echo "  FAIL  $label — expected '$expected' in: $plain"
    FAIL=$(( FAIL + 1 ))
  fi
}

assert_not_contains() {
  local label="$1" output="$2" unexpected="$3"
  local plain
  plain=$(printf '%b' "$output" | sed 's/\x1b\[[0-9;]*m//g')
  if [[ "$plain" != *"$unexpected"* ]]; then
    echo "  PASS  $label"
    PASS=$(( PASS + 1 ))
  else
    echo "  FAIL  $label — unexpected '$unexpected' in: $plain"
    FAIL=$(( FAIL + 1 ))
  fi
}

run_status() {
  # Reset compact state before each run to avoid cross-test interference
  rm -f "$HOME/.claude/hud-compact"
  echo "$1" | CLAUDE_HUD_THEME="${2:-default}" bash "$STATUS" 2>/dev/null
}

echo "Running claude-mini-hud smoke tests..."
echo ""

# ── Test 1: Basic output with low context ────────────────────────────────────
fixture='{"context_window":{"used_percentage":25},"rate_limits":{"five_hour":{"used_percentage":10}},"cost":{"total_duration_ms":300000,"total_lines_added":5,"total_lines_removed":2},"model":{"display_name":"Claude Opus 4"}}'
out=$(run_status "$fixture")

assert_contains "callsign normal" "$out" "✦CC✦"
assert_contains "ctx percentage" "$out" "25%"
assert_contains "duration 5m" "$out" "5m"
assert_contains "lines added" "$out" "+5"
assert_contains "lines removed" "$out" "-2"

# ── Test 2: Warning state at 75% context ─────────────────────────────────────
fixture='{"context_window":{"used_percentage":75},"rate_limits":{"five_hour":{"used_percentage":5}},"cost":{"total_duration_ms":60000},"model":{"display_name":"Claude"}}'
out=$(run_status "$fixture")

assert_contains "callsign warning" "$out" "◈CC◈"
assert_contains "ctx 75%" "$out" "75%"

# ── Test 3: Critical state at 95% context ────────────────────────────────────
fixture='{"context_window":{"used_percentage":95},"rate_limits":{"five_hour":{"used_percentage":5}},"cost":{"total_duration_ms":60000},"model":{"display_name":"Claude"}}'
out=$(run_status "$fixture")

assert_contains "callsign critical" "$out" "!CC!"

# ── Test 4: Battery thresholds ───────────────────────────────────────────────
# 1% used = 99% remaining = 5 bars
fixture='{"context_window":{"used_percentage":10},"rate_limits":{"five_hour":{"used_percentage":1}},"cost":{"total_duration_ms":60000},"model":{"display_name":"Claude"}}'
out=$(run_status "$fixture")
assert_contains "battery 5 bars" "$out" "▮▮▮▮▮"

# 60% used = 40% remaining = 2 bars
fixture='{"context_window":{"used_percentage":10},"rate_limits":{"five_hour":{"used_percentage":60}},"cost":{"total_duration_ms":60000},"model":{"display_name":"Claude"}}'
out=$(run_status "$fixture")
assert_contains "battery 2 bars" "$out" "▮▮▯▯▯"

# 95% used = 5% remaining = 0 bars
fixture='{"context_window":{"used_percentage":10},"rate_limits":{"five_hour":{"used_percentage":95}},"cost":{"total_duration_ms":60000},"model":{"display_name":"Claude"}}'
out=$(run_status "$fixture")
assert_contains "battery 0 bars" "$out" "▯▯▯▯▯"

# ── Test 5: No diff when zero lines ──────────────────────────────────────────
fixture='{"context_window":{"used_percentage":10},"rate_limits":{"five_hour":{"used_percentage":5}},"cost":{"total_duration_ms":60000,"total_lines_added":0,"total_lines_removed":0},"model":{"display_name":"Claude"}}'
out=$(run_status "$fixture")
assert_not_contains "no diff at zero" "$out" "+0"

# ── Test 6: Duration formatting ──────────────────────────────────────────────
# 90 minutes = 1h 30m
fixture='{"context_window":{"used_percentage":10},"rate_limits":{"five_hour":{"used_percentage":5}},"cost":{"total_duration_ms":5400000},"model":{"display_name":"Claude"}}'
out=$(run_status "$fixture")
assert_contains "duration 1h30m" "$out" "1h 30m"

# ── Test 7: Empty/invalid input ──────────────────────────────────────────────
out=$(run_status "")
assert_contains "empty input exits clean" "$out" ""

out=$(run_status "not json")
assert_contains "bad json exits clean" "$out" ""

# ── Test 8: Themes produce output ────────────────────────────────────────────
fixture='{"context_window":{"used_percentage":50},"rate_limits":{"five_hour":{"used_percentage":20}},"cost":{"total_duration_ms":120000},"model":{"display_name":"Claude"}}'
for theme in default synthwave ghost matrix blueprint vaporwave lava-lamp; do
  out=$(run_status "$fixture" "$theme")
  assert_contains "theme $theme renders" "$out" "50%"
done

# ── Results ──────────────────────────────────────────────────────────────────
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
(( FAIL > 0 )) && exit 1
exit 0
