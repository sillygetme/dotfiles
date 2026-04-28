#!/usr/bin/env bash

set -euo pipefail

config="$HOME/.config/cava/config-sdl"

pkill -f 'cava -p .*/config-sdl' >/dev/null 2>&1 || true

read -r width height _pos_x pos_y _scale < <(
  hyprctl monitors -j | jq -r '.[] | select(.focused == true) | "\(.width) \(.height) \(.x) \(.y) \(.scale)"' | head -n 1
)

if [[ -z "${width:-}" || -z "${height:-}" ]]; then
  width=1920
  height=1080
  pos_y=0
fi

bar_width=$(( width / 3 ))
bar_height=$(( height * 16 / 100 ))
bar_x=-1
bar_y=$(( pos_y + height - bar_height - 24 ))

sed -i \
  -e "s/^sdl_width = .*/sdl_width = ${bar_width}/" \
  -e "s/^sdl_height = .*/sdl_height = ${bar_height}/" \
  -e "s/^sdl_x = .*/sdl_x = ${bar_x}/" \
  -e "s/^sdl_y = .*/sdl_y = ${bar_y}/" \
  "$config"

exec cava -p "$config"
