#!/usr/bin/env bash

set -euo pipefail

config="$HOME/.config/glava/rc.glsl"

read -r width height _pos_x pos_y _scale < <(
  hyprctl monitors -j | jq -r '.[] | select(.focused == true) | "\(.width) \(.height) \(.x) \(.y) \(.scale)"' | head -n 1
)

if [[ -z "${width:-}" || -z "${height:-}" ]]; then
  width=1920
  height=1080
  pos_y=0
fi

glava_width=$(( width / 3 ))
glava_height=160
glava_x=$(( (width - glava_width) / 2 ))
glava_y=$(( pos_y + height - glava_height - 10 ))

sed -i \
  -e "s/^#request setgeometry .*/#request setgeometry ${glava_x} ${glava_y} ${glava_width} ${glava_height}/" \
  "$config"

pkill -x glava >/dev/null 2>&1 || true
exec glava
