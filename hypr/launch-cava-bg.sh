#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${CAVA_BG_FORCE_RESTART:-}" ]] && pgrep -af "kitty.*kitten panel .*cava-bg" >/dev/null; then
  exit 0
fi

monitor_name="eDP-1"
panel_width=640
panel_height=270
margin_left=640
margin_bottom=10
margin_right=640

kitty +kitten panel \
  --edge=none \
  --app-id cava-bg \
  --output-name "$monitor_name" \
  --lines=${panel_height}px \
  --columns=${panel_width}px \
  --margin-left=${margin_left} \
  --margin-bottom=${margin_bottom} \
  --margin-right=${margin_right} \
  --layer=background \
  --focus-policy=not-allowed \
  -o font_size=4 \
  -o background_opacity=0 \
  cava -p "$HOME/.config/cava/config-bg"
