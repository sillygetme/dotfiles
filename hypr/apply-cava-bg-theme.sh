#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAVA_CONFIG="$HOME/.config/cava/config-bg"
COLORS_SH="${XDG_CACHE_HOME:-$HOME/.cache}/wal/colors.sh"
LAUNCHER="$SCRIPT_DIR/launch-cava-bg.sh"
LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/cava-bg-theme.log"

if [[ ! -f "$COLORS_SH" || ! -f "$CAVA_CONFIG" ]]; then
  exit 0
fi

# shellcheck disable=SC1090
set +u
source "$COLORS_SH"
set -u

GRADIENT_SLOT_1="${GRADIENT_SLOT_1:-9}"
GRADIENT_SLOT_2="${GRADIENT_SLOT_2:-7}"
GRADIENT_SLOT_3="${GRADIENT_SLOT_3:-12}"

slot_to_color() {
  local slot="$1"
  local var_name="color${slot}"
  printf '%s\n' "${!var_name:-}"
}

gradient_1="$(slot_to_color "$GRADIENT_SLOT_1")"
gradient_2="$(slot_to_color "$GRADIENT_SLOT_2")"
gradient_3="$(slot_to_color "$GRADIENT_SLOT_3")"

gradient_1="${gradient_1:-$color1}"
gradient_2="${gradient_2:-$color2}"
gradient_3="${gradient_3:-$color3}"

tmp_file="$(mktemp)"
awk -v c1="$gradient_1" -v c2="$gradient_2" -v c3="$gradient_3" '
  BEGIN { in_color = 0; color_done = 0 }
  /^\[color\][[:space:]]*$/ {
    in_color = 1
    color_done = 1
    print "[color]"
    print "gradient = 1"
    print "gradient_color_1 = '\''" c1 "'\''"
    print "gradient_color_2 = '\''" c2 "'\''"
    print "gradient_color_3 = '\''" c3 "'\''"
    next
  }
  /^\[[^]]+\][[:space:]]*$/ {
    in_color = 0
    print
    next
  }
  in_color { next }
  { print }
  END {
    if (!color_done) {
      print ""
      print "[color]"
      print "gradient = 1"
      print "gradient_color_1 = '\''" c1 "'\''"
      print "gradient_color_2 = '\''" c2 "'\''"
      print "gradient_color_3 = '\''" c3 "'\''"
    }
  }
' "$CAVA_CONFIG" > "$tmp_file"

mv "$tmp_file" "$CAVA_CONFIG"

printf '%s slots:%s,%s,%s colors:%s %s %s\n' "$(date '+%F %T')" "$GRADIENT_SLOT_1" "$GRADIENT_SLOT_2" "$GRADIENT_SLOT_3" "$gradient_1" "$gradient_2" "$gradient_3" >> "$LOG_FILE"

pkill kitty >/dev/null 2>&1 || true
sleep 0.5

if [[ -x "$LAUNCHER" ]]; then
  nohup env CAVA_BG_FORCE_RESTART=1 "$LAUNCHER" >/dev/null 2>&1 &
fi
