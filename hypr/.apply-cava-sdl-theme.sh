#!/usr/bin/env bash

set -euo pipefail

colors_sh="$HOME/.cache/wal/colors.sh"
config="$HOME/.config/cava/config-sdl"

if [[ ! -f "$colors_sh" ]]; then
  exit 0
fi

# shellcheck disable=SC1090
source "$colors_sh"

gradient1="${color12:-$foreground}"
gradient2="${color13:-$foreground}"
background="${background:-#000000}"

sed -i \
  -e "s/^gradient_color_1 = .*/gradient_color_1 = '${gradient1}'/" \
  -e "s/^gradient_color_2 = .*/gradient_color_2 = '${gradient2}'/" \
  -e "s/^background = .*/background = '${background}'/" \
  "$config"

if pgrep -f 'cava -p .*/config-sdl' >/dev/null 2>&1; then
  "$HOME/.config/hypr/launch-cava-sdl.sh" >/dev/null 2>&1 &
fi
