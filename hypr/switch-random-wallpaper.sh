#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/wpps}"
TRANSITION_TYPE="${TRANSITION_TYPE:-grow}"
TRANSITION_POS="${TRANSITION_POS:-center}"
TRANSITION_DURATION="${TRANSITION_DURATION:-10}"
TRANSITION_FPS="${TRANSITION_FPS:-60}"
TRANSITION_STEP="${TRANSITION_STEP:-90}"
CAVA_THEME_TRANSITION_FRACTION="${CAVA_THEME_TRANSITION_FRACTION:-0.25}"
STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-last-wallpaper"
HYPRLOCK_WALLPAPER_LINK="${XDG_CACHE_HOME:-$HOME/.cache}/hyprlock-wallpaper"
LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/rotate-random-wallpaper.log"
THEME_TRANSITION_DELAY="$(awk "BEGIN { printf \"%.3f\", $TRANSITION_DURATION / 2 }")"
CAVA_TRANSITION_DELAY="$(awk "BEGIN { printf \"%.3f\", $TRANSITION_DURATION * $CAVA_THEME_TRANSITION_FRACTION }")"

if ! command -v swww >/dev/null 2>&1; then
  echo "error: swww is required for animated wallpaper transitions" >&2
  exit 1
fi

if [ ! -d "$WALLPAPER_DIR" ]; then
  printf '%s error wallpaper directory not found: %s\n' "$(date '+%F %T')" "$WALLPAPER_DIR" >> "$LOG_FILE"
  echo "error: wallpaper directory not found: $WALLPAPER_DIR" >&2
  exit 1
fi

mapfile -t wallpapers < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( \
  -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.jxl' \
\) | sort)

if [ "${#wallpapers[@]}" -eq 0 ]; then
  printf '%s error no wallpapers found in: %s\n' "$(date '+%F %T')" "$WALLPAPER_DIR" >> "$LOG_FILE"
  echo "error: no wallpapers found in $WALLPAPER_DIR" >&2
  exit 1
fi

if ! pgrep -x swww-daemon >/dev/null 2>&1; then
  swww-daemon >/dev/null 2>&1 &
  sleep 1
fi

last_wallpaper=""
if [ -f "$STATE_FILE" ]; then
  last_wallpaper="$(cat "$STATE_FILE")"
fi

wallpaper="$(printf '%s\n' "${wallpapers[@]}" | shuf -n 1)"
if [ "${#wallpapers[@]}" -gt 1 ]; then
  while [ "$wallpaper" = "$last_wallpaper" ]; do
    wallpaper="$(printf '%s\n' "${wallpapers[@]}" | shuf -n 1)"
  done
fi

swww img "$wallpaper" \
  --transition-type "$TRANSITION_TYPE" \
  --transition-pos "$TRANSITION_POS" \
  --transition-duration "$TRANSITION_DURATION" \
  --transition-fps "$TRANSITION_FPS" \
  --transition-step "$TRANSITION_STEP"

printf '%s wallpaper %s\n' "$(date '+%F %T')" "$wallpaper" >> "$LOG_FILE"
printf '%s' "$wallpaper" > "$STATE_FILE"
ln -sfn "$wallpaper" "$HYPRLOCK_WALLPAPER_LINK"

if command -v wal >/dev/null 2>&1 && [ -x "$SCRIPT_DIR/apply-cava-bg-theme.sh" ]; then
  sleep "$CAVA_TRANSITION_DELAY"
  if wal -i "$wallpaper" -n >/dev/null 2>&1; then
    "$SCRIPT_DIR/apply-cava-bg-theme.sh" >> "$LOG_FILE" 2>&1 || true
  else
    printf '%s error early wal/apply-cava-bg-theme failed for: %s\n' "$(date '+%F %T')" "$wallpaper" >> "$LOG_FILE"
  fi
fi

if [ -x "$SCRIPT_DIR/wal-apply-theme.sh" ]; then
  remaining_delay="$(awk -v full="$THEME_TRANSITION_DELAY" -v early="$CAVA_TRANSITION_DELAY" 'BEGIN { d = full - early; if (d < 0) d = 0; printf "%.3f", d }')"
  sleep "$remaining_delay"
  if ! SKIP_CAVA_BG_THEME=1 "$SCRIPT_DIR/wal-apply-theme.sh" "$wallpaper" >> "$LOG_FILE" 2>&1; then
    printf '%s error wal-apply-theme failed for: %s\n' "$(date '+%F %T')" "$wallpaper" >> "$LOG_FILE"
  fi
fi
